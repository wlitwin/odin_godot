package godot

import __bindgen_gde "godot:gdext"

Editor_Inspector_Constants :: enum {
}



editor_inspector_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_inspector_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_inspector :: proc "contextless" () -> Editor_Inspector {
    return cast(Editor_Inspector)__bindgen_gde.classdb_construct_object(editor_inspector_name_ref())
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
editor_inspector_instantiate_property_editor :: proc "contextless" (
    object_: Object,
    type_: __bindgen_gde.Variant_Type,
    path_: String,
    hint_: Property_Hint,
    hint_text_: String,
    usage_: Int,
    wide_: Bool,
) -> (ret: Editor_Property) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("instantiate_property_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1429914152)
    }
    object_ := object_
    type_ := type_
    path_ := path_
    hint_ := hint_
    hint_text_ := hint_text_
    usage_ := usage_
    wide_ := wide_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &type_,
        &path_,
        &hint_,
        &hint_text_,
        &usage_,
        &wide_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

editor_inspector_create_default_inspector :: proc "contextless" (
    filter_line_edit_: Line_Edit,
) -> (ret: Editor_Inspector) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_default_inspector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2419746798)
    }
    filter_line_edit_ := filter_line_edit_
    args := []__bindgen_gde.TypePtr {
        &filter_line_edit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


editor_inspector_edit :: proc "contextless" (
    self: Editor_Inspector,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("edit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_get_selected_path :: proc "contextless" (
    self: Editor_Inspector,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selected_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_inspector_get_edited_object :: proc "contextless" (
    self: Editor_Inspector,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_edited_object", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2050059866)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_inspector_collapse_all_folding :: proc "contextless" (
    self: Editor_Inspector,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("collapse_all_folding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_expand_all_folding :: proc "contextless" (
    self: Editor_Inspector,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("expand_all_folding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_expand_revertable :: proc "contextless" (
    self: Editor_Inspector,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("expand_revertable", true)
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
editor_inspector_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorInspector", true)
}

@(private = "file")
__class_name: String_Name