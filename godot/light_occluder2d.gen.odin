package godot

import __bindgen_gde "godot:gdext"

Light_Occluder2d_Constants :: enum {
}



light_occluder2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

light_occluder2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_light_occluder2d :: proc "contextless" () -> Light_Occluder2d {
    return cast(Light_Occluder2d)__bindgen_gde.classdb_construct_object(light_occluder2d_name_ref())
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

light_occluder2d_set_occluder_polygon :: proc "contextless" (
    self: Light_Occluder2d,
    polygon_: Occluder_Polygon2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_occluder_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3258315893)
    }
    self := self
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light_occluder2d_get_occluder_polygon :: proc "contextless" (
    self: Light_Occluder2d,
) -> (ret: Occluder_Polygon2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occluder_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3962317075)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light_occluder2d_set_occluder_light_mask :: proc "contextless" (
    self: Light_Occluder2d,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_occluder_light_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light_occluder2d_get_occluder_light_mask :: proc "contextless" (
    self: Light_Occluder2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occluder_light_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light_occluder2d_set_as_sdf_collision :: proc "contextless" (
    self: Light_Occluder2d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_as_sdf_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light_occluder2d_is_set_as_sdf_collision :: proc "contextless" (
    self: Light_Occluder2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_set_as_sdf_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
light_occluder2d_get_occluder :: proc "contextless" (self: Light_Occluder2d) -> Occluder_Polygon2d {
    return light_occluder2d_get_occluder_polygon(self)
}
light_occluder2d_set_occluder :: proc "contextless" (self: Light_Occluder2d, value: Occluder_Polygon2d) {
    light_occluder2d_set_occluder_polygon(self, value)
}
light_occluder2d_get_sdf_collision :: proc "contextless" (self: Light_Occluder2d) -> Bool {
    return light_occluder2d_is_set_as_sdf_collision(self)
}
light_occluder2d_set_sdf_collision :: proc "contextless" (self: Light_Occluder2d, value: Bool) {
    light_occluder2d_set_as_sdf_collision(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
light_occluder2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("LightOccluder2D", true)
}

@(private = "file")
__class_name: String_Name