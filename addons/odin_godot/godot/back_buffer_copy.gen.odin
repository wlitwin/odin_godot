package godot

import __bindgen_gde "godot:gdext"

Back_Buffer_Copy_Constants :: enum {
}
Back_Buffer_Copy_Copy_Mode :: enum int {
    Copy_Mode_Disabled = 0,
    Copy_Mode_Rect = 1,
    Copy_Mode_Viewport = 2,
}



back_buffer_copy_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

back_buffer_copy_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_back_buffer_copy :: proc "contextless" () -> Back_Buffer_Copy {
    return __bindgen_gde.classdb_construct_object(back_buffer_copy_name_ref())
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

back_buffer_copy_set_rect :: proc "contextless" (
    self: Back_Buffer_Copy,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2046264180)
    }
    self := self
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

back_buffer_copy_get_rect :: proc "contextless" (
    self: Back_Buffer_Copy,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639390495)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

back_buffer_copy_set_copy_mode :: proc "contextless" (
    self: Back_Buffer_Copy,
    copy_mode_: Back_Buffer_Copy_Copy_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_copy_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1713538590)
    }
    self := self
    copy_mode_ := copy_mode_
    args := []__bindgen_gde.TypePtr {
        &copy_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

back_buffer_copy_get_copy_mode :: proc "contextless" (
    self: Back_Buffer_Copy,
) -> (ret: Back_Buffer_Copy_Copy_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_copy_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3271169440)
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
back_buffer_copy_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("BackBufferCopy", true)
}

@(private = "file")
__class_name: String_Name