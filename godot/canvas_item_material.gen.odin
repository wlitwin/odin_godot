package godot

import __bindgen_gde "godot:gdext"

Canvas_Item_Material_Constants :: enum {
}
Canvas_Item_Material_Blend_Mode :: enum int {
    Blend_Mode_Mix = 0,
    Blend_Mode_Add = 1,
    Blend_Mode_Sub = 2,
    Blend_Mode_Mul = 3,
    Blend_Mode_Premult_Alpha = 4,
}
Canvas_Item_Material_Light_Mode :: enum int {
    Light_Mode_Normal = 0,
    Light_Mode_Unshaded = 1,
    Light_Mode_Light_Only = 2,
}



canvas_item_material_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

canvas_item_material_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_canvas_item_material :: proc "contextless" () -> Canvas_Item_Material {
    return cast(Canvas_Item_Material)__bindgen_gde.classdb_construct_object(canvas_item_material_name_ref())
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

canvas_item_material_set_blend_mode :: proc "contextless" (
    self: Canvas_Item_Material,
    blend_mode_: Canvas_Item_Material_Blend_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1786054936)
    }
    self := self
    blend_mode_ := blend_mode_
    args := []__bindgen_gde.TypePtr {
        &blend_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_material_get_blend_mode :: proc "contextless" (
    self: Canvas_Item_Material,
) -> (ret: Canvas_Item_Material_Blend_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3318684035)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_material_set_light_mode :: proc "contextless" (
    self: Canvas_Item_Material,
    light_mode_: Canvas_Item_Material_Light_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_light_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 628074070)
    }
    self := self
    light_mode_ := light_mode_
    args := []__bindgen_gde.TypePtr {
        &light_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_material_get_light_mode :: proc "contextless" (
    self: Canvas_Item_Material,
) -> (ret: Canvas_Item_Material_Light_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_light_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3863292382)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_material_set_particles_animation :: proc "contextless" (
    self: Canvas_Item_Material,
    particles_anim_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particles_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    particles_anim_ := particles_anim_
    args := []__bindgen_gde.TypePtr {
        &particles_anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_material_get_particles_animation :: proc "contextless" (
    self: Canvas_Item_Material,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particles_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_material_set_particles_anim_h_frames :: proc "contextless" (
    self: Canvas_Item_Material,
    frames_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particles_anim_h_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    frames_ := frames_
    args := []__bindgen_gde.TypePtr {
        &frames_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_material_get_particles_anim_h_frames :: proc "contextless" (
    self: Canvas_Item_Material,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particles_anim_h_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_material_set_particles_anim_v_frames :: proc "contextless" (
    self: Canvas_Item_Material,
    frames_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particles_anim_v_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    frames_ := frames_
    args := []__bindgen_gde.TypePtr {
        &frames_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_material_get_particles_anim_v_frames :: proc "contextless" (
    self: Canvas_Item_Material,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particles_anim_v_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_material_set_particles_anim_loop :: proc "contextless" (
    self: Canvas_Item_Material,
    loop_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particles_anim_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    loop_ := loop_
    args := []__bindgen_gde.TypePtr {
        &loop_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_material_get_particles_anim_loop :: proc "contextless" (
    self: Canvas_Item_Material,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particles_anim_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
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
canvas_item_material_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CanvasItemMaterial", true)
}

@(private = "file")
__class_name: String_Name