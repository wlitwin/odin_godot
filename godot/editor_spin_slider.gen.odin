package godot

import __bindgen_gde "godot:gdext"

Editor_Spin_Slider_Constants :: enum {
}
Editor_Spin_Slider_Control_State :: enum int {
    Control_State_Default = 0,
    Control_State_Prefer_Slider = 1,
    Control_State_Hide = 2,
}



editor_spin_slider_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_spin_slider_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_spin_slider :: proc "contextless" () -> Editor_Spin_Slider {
    return __bindgen_gde.classdb_construct_object(editor_spin_slider_name_ref())
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

editor_spin_slider_set_label :: proc "contextless" (
    self: Editor_Spin_Slider,
    label_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    label_ := label_
    args := []__bindgen_gde.TypePtr {
        &label_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_get_label :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_spin_slider_set_suffix :: proc "contextless" (
    self: Editor_Spin_Slider,
    suffix_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_suffix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    suffix_ := suffix_
    args := []__bindgen_gde.TypePtr {
        &suffix_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_get_suffix :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_suffix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_spin_slider_set_read_only :: proc "contextless" (
    self: Editor_Spin_Slider,
    read_only_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_read_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    read_only_ := read_only_
    args := []__bindgen_gde.TypePtr {
        &read_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_is_read_only :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_read_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_spin_slider_set_flat :: proc "contextless" (
    self: Editor_Spin_Slider,
    flat_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    flat_ := flat_
    args := []__bindgen_gde.TypePtr {
        &flat_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_is_flat :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_flat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_spin_slider_set_control_state :: proc "contextless" (
    self: Editor_Spin_Slider,
    state_: Editor_Spin_Slider_Control_State,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_control_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1324557109)
    }
    self := self
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_get_control_state :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: Editor_Spin_Slider_Control_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_control_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3406006200)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_spin_slider_set_hide_slider :: proc "contextless" (
    self: Editor_Spin_Slider,
    hide_slider_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hide_slider", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    hide_slider_ := hide_slider_
    args := []__bindgen_gde.TypePtr {
        &hide_slider_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_is_hiding_slider :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_hiding_slider", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_spin_slider_set_editing_integer :: proc "contextless" (
    self: Editor_Spin_Slider,
    editing_integer_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_editing_integer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    editing_integer_ := editing_integer_
    args := []__bindgen_gde.TypePtr {
        &editing_integer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_is_editing_integer :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editing_integer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_spin_slider_set_deferred_drag_mode_enabled :: proc "contextless" (
    self: Editor_Spin_Slider,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_deferred_drag_mode_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3216645846)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_spin_slider_is_deferred_drag_mode_enabled :: proc "contextless" (
    self: Editor_Spin_Slider,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_deferred_drag_mode_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
editor_spin_slider_get_read_only :: proc "contextless" (self: Editor_Spin_Slider) -> Bool {
    return editor_spin_slider_is_read_only(self)
}
editor_spin_slider_get_flat :: proc "contextless" (self: Editor_Spin_Slider) -> Bool {
    return editor_spin_slider_is_flat(self)
}
editor_spin_slider_get_hide_slider :: proc "contextless" (self: Editor_Spin_Slider) -> Bool {
    return editor_spin_slider_is_hiding_slider(self)
}
editor_spin_slider_get_editing_integer :: proc "contextless" (self: Editor_Spin_Slider) -> Bool {
    return editor_spin_slider_is_editing_integer(self)
}
editor_spin_slider_get_deferred_drag_mode :: proc "contextless" (self: Editor_Spin_Slider) -> Bool {
    return editor_spin_slider_is_deferred_drag_mode_enabled(self)
}
editor_spin_slider_set_deferred_drag_mode :: proc "contextless" (self: Editor_Spin_Slider, value: Bool) {
    editor_spin_slider_set_deferred_drag_mode_enabled(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_spin_slider_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorSpinSlider", true)
}

@(private = "file")
__class_name: String_Name