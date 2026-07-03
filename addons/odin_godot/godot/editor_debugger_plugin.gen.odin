package godot

import __bindgen_gde "godot:gdext"

Editor_Debugger_Plugin_Constants :: enum {
}



editor_debugger_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_debugger_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_debugger_plugin :: proc "contextless" () -> Editor_Debugger_Plugin {
    return cast(Editor_Debugger_Plugin)__bindgen_gde.classdb_construct_object(editor_debugger_plugin_name_ref())
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

editor_debugger_plugin__setup_session :: proc "contextless" (
    self: Editor_Debugger_Plugin,
    session_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_setup_session", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    session_id_ := session_id_
    args := []__bindgen_gde.TypePtr {
        &session_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_debugger_plugin__has_capture :: proc "contextless" (
    self: Editor_Debugger_Plugin,
    capture_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_has_capture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    capture_ := capture_
    args := []__bindgen_gde.TypePtr {
        &capture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_debugger_plugin__capture :: proc "contextless" (
    self: Editor_Debugger_Plugin,
    message_: String,
    data_: Array,
    session_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_capture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2607901833)
    }
    self := self
    message_ := message_
    data_ := data_
    session_id_ := session_id_
    args := []__bindgen_gde.TypePtr {
        &message_,
        &data_,
        &session_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_debugger_plugin__goto_script_line :: proc "contextless" (
    self: Editor_Debugger_Plugin,
    script_: Script,
    line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_goto_script_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1208513123)
    }
    self := self
    script_ := script_
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &script_,
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_debugger_plugin__breakpoints_cleared_in_tree :: proc "contextless" (
    self: Editor_Debugger_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_breakpoints_cleared_in_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_debugger_plugin__breakpoint_set_in_tree :: proc "contextless" (
    self: Editor_Debugger_Plugin,
    script_: Script,
    line_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_breakpoint_set_in_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2338735218)
    }
    self := self
    script_ := script_
    line_ := line_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &script_,
        &line_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_debugger_plugin_get_session :: proc "contextless" (
    self: Editor_Debugger_Plugin,
    id_: Int,
) -> (ret: Editor_Debugger_Session) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_session", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3061968499)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_debugger_plugin_get_sessions :: proc "contextless" (
    self: Editor_Debugger_Plugin,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sessions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
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
editor_debugger_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorDebuggerPlugin", true)
}

@(private = "file")
__class_name: String_Name