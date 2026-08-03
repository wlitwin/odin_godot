package godot

import __bindgen_gde "godot:gdext"

Camera_Server_Constants :: enum {
}
Camera_Server_Feed_Image :: enum int {
    Feed_Rgba_Image = 0,
    Feed_Ycbcr_Image = 0,
    Feed_Y_Image = 0,
    Feed_Cbcr_Image = 1,
}



camera_server_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

camera_server_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_camera_server :: proc "contextless" () -> Camera_Server {
    return cast(Camera_Server)__bindgen_gde.classdb_construct_object(camera_server_name_ref())
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

camera_server_set_monitoring_feeds :: proc "contextless" (
    self: Camera_Server,
    is_monitoring_feeds_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_monitoring_feeds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    is_monitoring_feeds_ := is_monitoring_feeds_
    args := []__bindgen_gde.TypePtr {
        &is_monitoring_feeds_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_server_is_monitoring_feeds :: proc "contextless" (
    self: Camera_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_monitoring_feeds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_server_get_feed :: proc "contextless" (
    self: Camera_Server,
    index_: Int,
) -> (ret: Camera_Feed) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_feed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 361927068)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_server_get_feed_count :: proc "contextless" (
    self: Camera_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_feed_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_server_feeds :: proc "contextless" (
    self: Camera_Server,
) -> (ret: Typed_Array(Camera_Feed)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("feeds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_server_add_feed :: proc "contextless" (
    self: Camera_Server,
    feed_: Camera_Feed,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_feed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3204782488)
    }
    self := self
    feed_ := feed_
    args := []__bindgen_gde.TypePtr {
        &feed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_server_remove_feed :: proc "contextless" (
    self: Camera_Server,
    feed_: Camera_Feed,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_feed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3204782488)
    }
    self := self
    feed_ := feed_
    args := []__bindgen_gde.TypePtr {
        &feed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
camera_server_get_monitoring_feeds :: proc "contextless" (self: Camera_Server) -> Bool {
    return camera_server_is_monitoring_feeds(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
camera_server_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CameraServer", true)
}

@(private = "file")
__class_name: String_Name