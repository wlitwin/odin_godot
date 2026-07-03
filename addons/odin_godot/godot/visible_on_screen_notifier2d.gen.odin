package godot

import __bindgen_gde "godot:gdext"

Visible_On_Screen_Notifier2d_Constants :: enum {
}



visible_on_screen_notifier2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visible_on_screen_notifier2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visible_on_screen_notifier2d :: proc "contextless" () -> Visible_On_Screen_Notifier2d {
    return __bindgen_gde.classdb_construct_object(visible_on_screen_notifier2d_name_ref())
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

visible_on_screen_notifier2d_set_rect :: proc "contextless" (
    self: Visible_On_Screen_Notifier2d,
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

visible_on_screen_notifier2d_get_rect :: proc "contextless" (
    self: Visible_On_Screen_Notifier2d,
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

visible_on_screen_notifier2d_set_show_rect :: proc "contextless" (
    self: Visible_On_Screen_Notifier2d,
    show_rect_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    show_rect_ := show_rect_
    args := []__bindgen_gde.TypePtr {
        &show_rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visible_on_screen_notifier2d_is_showing_rect :: proc "contextless" (
    self: Visible_On_Screen_Notifier2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visible_on_screen_notifier2d_is_on_screen :: proc "contextless" (
    self: Visible_On_Screen_Notifier2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_on_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
visible_on_screen_notifier2d_get_show_rect :: proc "contextless" (self: Visible_On_Screen_Notifier2d) -> Bool {
    return visible_on_screen_notifier2d_is_showing_rect(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
visible_on_screen_notifier2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisibleOnScreenNotifier2D", true)
}

@(private = "file")
__class_name: String_Name