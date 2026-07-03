package godot

import __bindgen_gde "godot:gdext"

Accept_Dialog_Constants :: enum {
}



accept_dialog_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

accept_dialog_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_accept_dialog :: proc "contextless" () -> Accept_Dialog {
    return __bindgen_gde.classdb_construct_object(accept_dialog_name_ref())
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

accept_dialog_get_ok_button :: proc "contextless" (
    self: Accept_Dialog,
) -> (ret: Button) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ok_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1856205918)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_get_label :: proc "contextless" (
    self: Accept_Dialog,
) -> (ret: Label) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 566733104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_set_hide_on_ok :: proc "contextless" (
    self: Accept_Dialog,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hide_on_ok", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accept_dialog_get_hide_on_ok :: proc "contextless" (
    self: Accept_Dialog,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hide_on_ok", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_set_close_on_escape :: proc "contextless" (
    self: Accept_Dialog,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_close_on_escape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accept_dialog_get_close_on_escape :: proc "contextless" (
    self: Accept_Dialog,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_close_on_escape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_add_button :: proc "contextless" (
    self: Accept_Dialog,
    text_: String,
    right_: Bool,
    action_: String,
) -> (ret: Button) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3328440682)
    }
    self := self
    text_ := text_
    right_ := right_
    action_ := action_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &right_,
        &action_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_add_cancel_button :: proc "contextless" (
    self: Accept_Dialog,
    name_: String,
) -> (ret: Button) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_cancel_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 242045556)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_remove_button :: proc "contextless" (
    self: Accept_Dialog,
    button_: Button,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2068354942)
    }
    self := self
    button_ := button_
    args := []__bindgen_gde.TypePtr {
        &button_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accept_dialog_register_text_enter :: proc "contextless" (
    self: Accept_Dialog,
    line_edit_: Line_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_text_enter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3714008017)
    }
    self := self
    line_edit_ := line_edit_
    args := []__bindgen_gde.TypePtr {
        &line_edit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accept_dialog_set_text :: proc "contextless" (
    self: Accept_Dialog,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accept_dialog_get_text :: proc "contextless" (
    self: Accept_Dialog,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_set_autowrap :: proc "contextless" (
    self: Accept_Dialog,
    autowrap_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_autowrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    autowrap_ := autowrap_
    args := []__bindgen_gde.TypePtr {
        &autowrap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accept_dialog_has_autowrap :: proc "contextless" (
    self: Accept_Dialog,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_autowrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accept_dialog_set_ok_button_text :: proc "contextless" (
    self: Accept_Dialog,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ok_button_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accept_dialog_get_ok_button_text :: proc "contextless" (
    self: Accept_Dialog,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ok_button_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
accept_dialog_get_dialog_text :: proc "contextless" (self: Accept_Dialog) -> String {
    return accept_dialog_get_text(self)
}
accept_dialog_set_dialog_text :: proc "contextless" (self: Accept_Dialog, value: String) {
    accept_dialog_set_text(self, value)
}
accept_dialog_get_dialog_hide_on_ok :: proc "contextless" (self: Accept_Dialog) -> Bool {
    return accept_dialog_get_hide_on_ok(self)
}
accept_dialog_set_dialog_hide_on_ok :: proc "contextless" (self: Accept_Dialog, value: Bool) {
    accept_dialog_set_hide_on_ok(self, value)
}
accept_dialog_get_dialog_close_on_escape :: proc "contextless" (self: Accept_Dialog) -> Bool {
    return accept_dialog_get_close_on_escape(self)
}
accept_dialog_set_dialog_close_on_escape :: proc "contextless" (self: Accept_Dialog, value: Bool) {
    accept_dialog_set_close_on_escape(self, value)
}
accept_dialog_get_dialog_autowrap :: proc "contextless" (self: Accept_Dialog) -> Bool {
    return accept_dialog_has_autowrap(self)
}
accept_dialog_set_dialog_autowrap :: proc "contextless" (self: Accept_Dialog, value: Bool) {
    accept_dialog_set_autowrap(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
accept_dialog_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AcceptDialog", true)
}

@(private = "file")
__class_name: String_Name