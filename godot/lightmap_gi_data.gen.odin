package godot

import __bindgen_gde "godot:gdext"

Lightmap_Gi_Data_Constants :: enum {
}
Lightmap_Gi_Data_Shadowmask_Mode :: enum int {
    Shadowmask_Mode_None = 0,
    Shadowmask_Mode_Replace = 1,
    Shadowmask_Mode_Overlay = 2,
}



lightmap_gi_data_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

lightmap_gi_data_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_lightmap_gi_data :: proc "contextless" () -> Lightmap_Gi_Data {
    return cast(Lightmap_Gi_Data)__bindgen_gde.classdb_construct_object(lightmap_gi_data_name_ref())
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

lightmap_gi_data_set_lightmap_textures :: proc "contextless" (
    self: Lightmap_Gi_Data,
    light_textures_: Typed_Array(Texture_Layered),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lightmap_textures", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    light_textures_ := light_textures_
    args := []__bindgen_gde.TypePtr {
        &light_textures_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_data_get_lightmap_textures :: proc "contextless" (
    self: Lightmap_Gi_Data,
) -> (ret: Typed_Array(Texture_Layered)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lightmap_textures", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_data_set_shadowmask_textures :: proc "contextless" (
    self: Lightmap_Gi_Data,
    shadowmask_textures_: Typed_Array(Texture_Layered),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadowmask_textures", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    shadowmask_textures_ := shadowmask_textures_
    args := []__bindgen_gde.TypePtr {
        &shadowmask_textures_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_data_get_shadowmask_textures :: proc "contextless" (
    self: Lightmap_Gi_Data,
) -> (ret: Typed_Array(Texture_Layered)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadowmask_textures", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_data_set_uses_spherical_harmonics :: proc "contextless" (
    self: Lightmap_Gi_Data,
    uses_spherical_harmonics_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uses_spherical_harmonics", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    uses_spherical_harmonics_ := uses_spherical_harmonics_
    args := []__bindgen_gde.TypePtr {
        &uses_spherical_harmonics_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_data_is_using_spherical_harmonics :: proc "contextless" (
    self: Lightmap_Gi_Data,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_spherical_harmonics", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_data_add_user :: proc "contextless" (
    self: Lightmap_Gi_Data,
    path_: Node_Path,
    uv_scale_: Rect2,
    slice_index_: Int,
    sub_instance_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_user", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4272570515)
    }
    self := self
    path_ := path_
    uv_scale_ := uv_scale_
    slice_index_ := slice_index_
    sub_instance_ := sub_instance_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &uv_scale_,
        &slice_index_,
        &sub_instance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_data_get_user_count :: proc "contextless" (
    self: Lightmap_Gi_Data,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_user_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_data_get_user_path :: proc "contextless" (
    self: Lightmap_Gi_Data,
    user_idx_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_user_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 408788394)
    }
    self := self
    user_idx_ := user_idx_
    args := []__bindgen_gde.TypePtr {
        &user_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_data_clear_users :: proc "contextless" (
    self: Lightmap_Gi_Data,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_users", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_data_set_light_texture :: proc "contextless" (
    self: Lightmap_Gi_Data,
    light_texture_: Texture_Layered,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_light_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1278366092)
    }
    self := self
    light_texture_ := light_texture_
    args := []__bindgen_gde.TypePtr {
        &light_texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_data_get_light_texture :: proc "contextless" (
    self: Lightmap_Gi_Data,
) -> (ret: Texture_Layered) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_light_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3984243839)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
lightmap_gi_data_get_uses_spherical_harmonics :: proc "contextless" (self: Lightmap_Gi_Data) -> Bool {
    return lightmap_gi_data_is_using_spherical_harmonics(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
lightmap_gi_data_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("LightmapGIData", true)
}

@(private = "file")
__class_name: String_Name