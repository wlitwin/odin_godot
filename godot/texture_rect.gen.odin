package godot

import __bindgen_gde "godot:gdext"

Texture_Rect_Constants :: enum {
}
Texture_Rect_Expand_Mode :: enum int {
    Expand_Keep_Size = 0,
    Expand_Ignore_Size = 1,
    Expand_Fit_Width = 2,
    Expand_Fit_Width_Proportional = 3,
    Expand_Fit_Height = 4,
    Expand_Fit_Height_Proportional = 5,
}
Texture_Rect_Stretch_Mode :: enum int {
    Stretch_Scale = 0,
    Stretch_Tile = 1,
    Stretch_Keep = 2,
    Stretch_Keep_Centered = 3,
    Stretch_Keep_Aspect = 4,
    Stretch_Keep_Aspect_Centered = 5,
    Stretch_Keep_Aspect_Covered = 6,
}



texture_rect_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

texture_rect_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_texture_rect :: proc "contextless" () -> Texture_Rect {
    return cast(Texture_Rect)__bindgen_gde.classdb_construct_object(texture_rect_name_ref())
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

texture_rect_set_texture :: proc "contextless" (
    self: Texture_Rect,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_rect_get_texture :: proc "contextless" (
    self: Texture_Rect,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_rect_set_expand_mode :: proc "contextless" (
    self: Texture_Rect,
    expand_mode_: Texture_Rect_Expand_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_expand_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1870766882)
    }
    self := self
    expand_mode_ := expand_mode_
    args := []__bindgen_gde.TypePtr {
        &expand_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_rect_get_expand_mode :: proc "contextless" (
    self: Texture_Rect,
) -> (ret: Texture_Rect_Expand_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_expand_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3863824733)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_rect_set_flip_h :: proc "contextless" (
    self: Texture_Rect,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flip_h", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_rect_is_flipped_h :: proc "contextless" (
    self: Texture_Rect,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_flipped_h", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_rect_set_flip_v :: proc "contextless" (
    self: Texture_Rect,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flip_v", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_rect_is_flipped_v :: proc "contextless" (
    self: Texture_Rect,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_flipped_v", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_rect_set_stretch_mode :: proc "contextless" (
    self: Texture_Rect,
    stretch_mode_: Texture_Rect_Stretch_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 58788729)
    }
    self := self
    stretch_mode_ := stretch_mode_
    args := []__bindgen_gde.TypePtr {
        &stretch_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_rect_get_stretch_mode :: proc "contextless" (
    self: Texture_Rect,
) -> (ret: Texture_Rect_Stretch_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 346396079)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
texture_rect_get_flip_h :: proc "contextless" (self: Texture_Rect) -> Bool {
    return texture_rect_is_flipped_h(self)
}
texture_rect_get_flip_v :: proc "contextless" (self: Texture_Rect) -> Bool {
    return texture_rect_is_flipped_v(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
texture_rect_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TextureRect", true)
}

@(private = "file")
__class_name: String_Name