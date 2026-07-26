package godot

import __bindgen_gde "godot:gdext"

Gd_Script_Language_Protocol_Constants :: enum {
}



gd_script_language_protocol_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gd_script_language_protocol_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gd_script_language_protocol :: proc "contextless" () -> Gd_Script_Language_Protocol {
    return __bindgen_gde.classdb_construct_object(gd_script_language_protocol_name_ref())
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

gd_script_language_protocol_get_text_document :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
) -> (ret: Gd_Script_Text_Document) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_document", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 770545799)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_language_protocol_get_workspace :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
) -> (ret: Gd_Script_Workspace) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_workspace", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 969295246)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_language_protocol_is_smart_resolve_enabled :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_smart_resolve_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_language_protocol_is_initialized :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_initialized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_language_protocol_initialize :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
    params_: Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("initialize", true)
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

gd_script_language_protocol_initialized :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
    params_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("initialized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1114965689)
    }
    self := self
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_language_protocol_on_client_connected :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("on_client_connected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_script_language_protocol_on_client_disconnected :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
    client_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("on_client_disconnected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    client_id_ := client_id_
    args := []__bindgen_gde.TypePtr {
        &client_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gd_script_language_protocol_notify_client :: proc "contextless" (
    self: Gd_Script_Language_Protocol,
    method_: String,
    params_: Variant,
    client_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("notify_client", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2511212011)
    }
    self := self
    method_ := method_
    params_ := params_
    client_id_ := client_id_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &params_,
        &client_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gd_script_language_protocol_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GDScriptLanguageProtocol", true)
}

@(private = "file")
__class_name: String_Name