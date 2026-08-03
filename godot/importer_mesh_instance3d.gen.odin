package godot

import __bindgen_gde "godot:gdext"

Importer_Mesh_Instance3d_Constants :: enum {
}



importer_mesh_instance3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

importer_mesh_instance3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_importer_mesh_instance3d :: proc "contextless" () -> Importer_Mesh_Instance3d {
    return cast(Importer_Mesh_Instance3d)__bindgen_gde.classdb_construct_object(importer_mesh_instance3d_name_ref())
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

importer_mesh_instance3d_set_mesh :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    mesh_: Importer_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2255166972)
    }
    self := self
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_mesh :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: Importer_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3161779525)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_skin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    skin_: Skin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3971435618)
    }
    self := self
    skin_ := skin_
    args := []__bindgen_gde.TypePtr {
        &skin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_skin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: Skin) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2074563878)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_skeleton_path :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    skeleton_path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skeleton_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    skeleton_path_ := skeleton_path_
    args := []__bindgen_gde.TypePtr {
        &skeleton_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_skeleton_path :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skeleton_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_layer_mask :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    layer_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_mask_ := layer_mask_
    args := []__bindgen_gde.TypePtr {
        &layer_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_layer_mask :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_cast_shadows_setting :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    shadow_casting_setting_: Geometry_Instance3d_Shadow_Casting_Setting,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cast_shadows_setting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 856677339)
    }
    self := self
    shadow_casting_setting_ := shadow_casting_setting_
    args := []__bindgen_gde.TypePtr {
        &shadow_casting_setting_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_cast_shadows_setting :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: Geometry_Instance3d_Shadow_Casting_Setting) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cast_shadows_setting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3383019359)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_visibility_range_end_margin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_end_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_visibility_range_end_margin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_end_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_visibility_range_end :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_visibility_range_end :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_visibility_range_begin_margin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_begin_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_visibility_range_begin_margin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_begin_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_visibility_range_begin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_visibility_range_begin :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_instance3d_set_visibility_range_fade_mode :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
    mode_: Geometry_Instance3d_Visibility_Range_Fade_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_fade_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1440117808)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_instance3d_get_visibility_range_fade_mode :: proc "contextless" (
    self: Importer_Mesh_Instance3d,
) -> (ret: Geometry_Instance3d_Visibility_Range_Fade_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_fade_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2067221882)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
importer_mesh_instance3d_get_cast_shadow :: proc "contextless" (self: Importer_Mesh_Instance3d) -> Geometry_Instance3d_Shadow_Casting_Setting {
    return importer_mesh_instance3d_get_cast_shadows_setting(self)
}
importer_mesh_instance3d_set_cast_shadow :: proc "contextless" (self: Importer_Mesh_Instance3d, value: Geometry_Instance3d_Shadow_Casting_Setting) {
    importer_mesh_instance3d_set_cast_shadows_setting(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
importer_mesh_instance3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ImporterMeshInstance3D", true)
}

@(private = "file")
__class_name: String_Name