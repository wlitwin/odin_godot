package godot

import __bindgen_gde "godot:gdext"

Sprite_Frames_Constants :: enum {
}



sprite_frames_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

sprite_frames_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_sprite_frames :: proc "contextless" () -> Sprite_Frames {
    return cast(Sprite_Frames)__bindgen_gde.classdb_construct_object(sprite_frames_name_ref())
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

sprite_frames_add_animation :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    anim_ := anim_
    args := []__bindgen_gde.TypePtr {
        &anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_has_animation :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    anim_ := anim_
    args := []__bindgen_gde.TypePtr {
        &anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_frames_duplicate_animation :: proc "contextless" (
    self: Sprite_Frames,
    anim_from_: String_Name,
    anim_to_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    anim_from_ := anim_from_
    anim_to_ := anim_to_
    args := []__bindgen_gde.TypePtr {
        &anim_from_,
        &anim_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_remove_animation :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    anim_ := anim_
    args := []__bindgen_gde.TypePtr {
        &anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_rename_animation :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    newname_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    anim_ := anim_
    newname_ := newname_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &newname_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_get_animation_names :: proc "contextless" (
    self: Sprite_Frames,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_animation_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_frames_set_animation_speed :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    fps_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_animation_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4135858297)
    }
    self := self
    anim_ := anim_
    fps_ := fps_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &fps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_get_animation_speed :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_animation_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2349060816)
    }
    self := self
    anim_ := anim_
    args := []__bindgen_gde.TypePtr {
        &anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_frames_set_animation_loop :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    loop_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_animation_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2524380260)
    }
    self := self
    anim_ := anim_
    loop_ := loop_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &loop_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_get_animation_loop :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_animation_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    anim_ := anim_
    args := []__bindgen_gde.TypePtr {
        &anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_frames_add_frame :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    texture_: Texture2d,
    duration_: f64,
    at_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1351332740)
    }
    self := self
    anim_ := anim_
    texture_ := texture_
    duration_ := duration_
    at_position_ := at_position_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &texture_,
        &duration_,
        &at_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_set_frame :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    idx_: Int,
    texture_: Texture2d,
    duration_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 56804795)
    }
    self := self
    anim_ := anim_
    idx_ := idx_
    texture_ := texture_
    duration_ := duration_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &idx_,
        &texture_,
        &duration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_remove_frame :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2415702435)
    }
    self := self
    anim_ := anim_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_get_frame_count :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frame_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2458036349)
    }
    self := self
    anim_ := anim_
    args := []__bindgen_gde.TypePtr {
        &anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_frames_get_frame_texture :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    idx_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frame_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2900517879)
    }
    self := self
    anim_ := anim_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_frames_get_frame_duration :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
    idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frame_duration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1129309260)
    }
    self := self
    anim_ := anim_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &anim_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_frames_clear :: proc "contextless" (
    self: Sprite_Frames,
    anim_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    anim_ := anim_
    args := []__bindgen_gde.TypePtr {
        &anim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_frames_clear_all :: proc "contextless" (
    self: Sprite_Frames,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
sprite_frames_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SpriteFrames", true)
}

@(private = "file")
__class_name: String_Name