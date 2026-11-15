package godot

import __bindgen_gde "godot:gdext"

Editor_File_Dialog_Constants :: enum {
}



editor_file_dialog_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_file_dialog_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_file_dialog :: proc "contextless" () -> Editor_File_Dialog {
    return cast(Editor_File_Dialog)__bindgen_gde.classdb_construct_object(editor_file_dialog_name_ref())
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

editor_file_dialog_add_side_menu :: proc "contextless" (
    self: Editor_File_Dialog,
    menu_: Control,
    title_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_side_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 402368861)
    }
    self := self
    menu_ := menu_
    title_ := title_
    args := []__bindgen_gde.TypePtr {
        &menu_,
        &title_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_file_dialog_set_disable_overwrite_warning :: proc "contextless" (
    self: Editor_File_Dialog,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_overwrite_warning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_file_dialog_is_overwrite_warning_disabled :: proc "contextless" (
    self: Editor_File_Dialog,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_overwrite_warning_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
editor_file_dialog_get_disable_overwrite_warning :: proc "contextless" (self: Editor_File_Dialog) -> Bool {
    return editor_file_dialog_is_overwrite_warning_disabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_file_dialog_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorFileDialog", true)
}

@(private = "file")
__class_name: String_Name