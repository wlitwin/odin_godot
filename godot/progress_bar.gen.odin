package godot

import __bindgen_gde "godot:gdext"

Progress_Bar_Constants :: enum {
}
Progress_Bar_Fill_Mode :: enum int {
    Fill_Begin_To_End = 0,
    Fill_End_To_Begin = 1,
    Fill_Top_To_Bottom = 2,
    Fill_Bottom_To_Top = 3,
}



progress_bar_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

progress_bar_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_progress_bar :: proc "contextless" () -> Progress_Bar {
    return __bindgen_gde.classdb_construct_object(progress_bar_name_ref())
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

progress_bar_set_fill_mode :: proc "contextless" (
    self: Progress_Bar,
    mode_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fill_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

progress_bar_get_fill_mode :: proc "contextless" (
    self: Progress_Bar,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fill_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

progress_bar_set_show_percentage :: proc "contextless" (
    self: Progress_Bar,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_percentage", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

progress_bar_is_percentage_shown :: proc "contextless" (
    self: Progress_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_percentage_shown", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

progress_bar_set_indeterminate :: proc "contextless" (
    self: Progress_Bar,
    indeterminate_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_indeterminate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    indeterminate_ := indeterminate_
    args := []__bindgen_gde.TypePtr {
        &indeterminate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

progress_bar_is_indeterminate :: proc "contextless" (
    self: Progress_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_indeterminate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

progress_bar_set_editor_preview_indeterminate :: proc "contextless" (
    self: Progress_Bar,
    preview_indeterminate_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_editor_preview_indeterminate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    preview_indeterminate_ := preview_indeterminate_
    args := []__bindgen_gde.TypePtr {
        &preview_indeterminate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

progress_bar_is_editor_preview_indeterminate_enabled :: proc "contextless" (
    self: Progress_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editor_preview_indeterminate_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
progress_bar_get_show_percentage :: proc "contextless" (self: Progress_Bar) -> Bool {
    return progress_bar_is_percentage_shown(self)
}
progress_bar_get_indeterminate :: proc "contextless" (self: Progress_Bar) -> Bool {
    return progress_bar_is_indeterminate(self)
}
progress_bar_get_editor_preview_indeterminate :: proc "contextless" (self: Progress_Bar) -> Bool {
    return progress_bar_is_editor_preview_indeterminate_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
progress_bar_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ProgressBar", true)
}

@(private = "file")
__class_name: String_Name