package godot

import __bindgen_gde "godot:gdext"

Camera_Texture_Constants :: enum {
}



camera_texture_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

camera_texture_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_camera_texture :: proc "contextless" () -> Camera_Texture {
    return cast(Camera_Texture)__bindgen_gde.classdb_construct_object(camera_texture_name_ref())
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

camera_texture_set_camera_feed_id :: proc "contextless" (
    self: Camera_Texture,
    feed_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_camera_feed_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    feed_id_ := feed_id_
    args := []__bindgen_gde.TypePtr {
        &feed_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_texture_get_camera_feed_id :: proc "contextless" (
    self: Camera_Texture,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_feed_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_texture_set_which_feed :: proc "contextless" (
    self: Camera_Texture,
    which_feed_: Camera_Server_Feed_Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_which_feed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1595299230)
    }
    self := self
    which_feed_ := which_feed_
    args := []__bindgen_gde.TypePtr {
        &which_feed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_texture_get_which_feed :: proc "contextless" (
    self: Camera_Texture,
) -> (ret: Camera_Server_Feed_Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_which_feed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 91039457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_texture_set_camera_active :: proc "contextless" (
    self: Camera_Texture,
    active_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_camera_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    active_ := active_
    args := []__bindgen_gde.TypePtr {
        &active_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_texture_get_camera_active :: proc "contextless" (
    self: Camera_Texture,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
camera_texture_get_camera_is_active :: proc "contextless" (self: Camera_Texture) -> Bool {
    return camera_texture_get_camera_active(self)
}
camera_texture_set_camera_is_active :: proc "contextless" (self: Camera_Texture, value: Bool) {
    camera_texture_set_camera_active(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
camera_texture_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CameraTexture", true)
}

@(private = "file")
__class_name: String_Name