package godot

import __bindgen_gde "godot:gdext"

Logger_Constants :: enum {
}
Logger_Error_Type :: enum int {
    Error_Type_Error = 0,
    Error_Type_Warning = 1,
    Error_Type_Script = 2,
    Error_Type_Shader = 3,
}



logger_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

logger_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_logger :: proc "contextless" () -> Logger {
    return cast(Logger)__bindgen_gde.classdb_construct_object(logger_name_ref())
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

logger__log_error :: proc "contextless" (
    self: Logger,
    function_: String,
    file_: String,
    line_: Int,
    code_: String,
    rationale_: String,
    editor_notify_: Bool,
    error_type_: Int,
    script_backtraces_: Typed_Array(Script_Backtrace),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_log_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 27079556)
    }
    self := self
    function_ := function_
    file_ := file_
    line_ := line_
    code_ := code_
    rationale_ := rationale_
    editor_notify_ := editor_notify_
    error_type_ := error_type_
    script_backtraces_ := script_backtraces_
    args := []__bindgen_gde.TypePtr {
        &function_,
        &file_,
        &line_,
        &code_,
        &rationale_,
        &editor_notify_,
        &error_type_,
        &script_backtraces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

logger__log_message :: proc "contextless" (
    self: Logger,
    message_: String,
    error_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_log_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678287736)
    }
    self := self
    message_ := message_
    error_ := error_
    args := []__bindgen_gde.TypePtr {
        &message_,
        &error_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
logger_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Logger", true)
}

@(private = "file")
__class_name: String_Name