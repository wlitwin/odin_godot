package godot

import __bindgen_gde "godot:gdext"

Gd_Script_Text_Document_Constants :: enum {
}



gd_script_text_document_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gd_script_text_document_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gd_script_text_document :: proc "contextless" () -> Gd_Script_Text_Document {
    return cast(Gd_Script_Text_Document)__bindgen_gde.classdb_construct_object(gd_script_text_document_name_ref())
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

gd_script_text_document_show_native_symbol_in_editor :: proc "contextless" (
    self: Gd_Script_Text_Document,
    symbol_id_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("show_native_symbol_in_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    symbol_id_ := symbol_id_
    args := []__bindgen_gde.TypePtr {
        &symbol_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_text_document_didOpen :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("didOpen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1114965689)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_text_document_didClose :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("didClose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1114965689)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_text_document_didChange :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("didChange", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1114965689)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_text_document_willSaveWaitUntil :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("willSaveWaitUntil", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1114965689)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_text_document_didSave :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("didSave", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1114965689)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_text_document_nativeSymbol :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("nativeSymbol", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3762224011)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_documentSymbol :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("documentSymbol", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_completion :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_resolve :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resolve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1333564645)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_rename :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1333564645)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_prepareRename :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("prepareRename", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3762224011)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_references :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("references", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_foldingRange :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("foldingRange", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_codeLens :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("codeLens", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_documentLink :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("documentLink", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_colorPresentation :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("colorPresentation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_hover :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hover", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3762224011)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_definition :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("definition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3877611628)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_declaration :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("declaration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3762224011)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_text_document_signatureHelp :: proc "contextless" (
    self: Gd_Script_Text_Document,
    params_: Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("signatureHelp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3762224011)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gd_script_text_document_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GDScriptTextDocument", true)
}

@(private = "file")
__class_name: String_Name