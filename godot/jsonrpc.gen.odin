package godot

import __bindgen_gde "godot:gdext"

Jsonrpc_Constants :: enum {
}
Jsonrpc_Error_Code :: enum int {
    Parse_Error = -32700,
    Invalid_Request = -32600,
    Method_Not_Found = -32601,
    Invalid_Params = -32602,
    Internal_Error = -32603,
}



jsonrpc_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

jsonrpc_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_jsonrpc :: proc "contextless" () -> Jsonrpc {
    return __bindgen_gde.classdb_construct_object(jsonrpc_name_ref())
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

jsonrpc_set_method :: proc "contextless" (
    self: Jsonrpc,
    name_: String,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_method", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2137474292)
    }
    self := self
    name_ := name_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

jsonrpc_process_action :: proc "contextless" (
    self: Jsonrpc,
    action_: Variant,
    recurse_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("process_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2963479484)
    }
    self := self
    action_ := action_
    recurse_ := recurse_
    args := []__bindgen_gde.TypePtr {
        &action_,
        &recurse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

jsonrpc_process_string :: proc "contextless" (
    self: Jsonrpc,
    action_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("process_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1703090593)
    }
    self := self
    action_ := action_
    args := []__bindgen_gde.TypePtr {
        &action_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

jsonrpc_make_request :: proc "contextless" (
    self: Jsonrpc,
    method_: String,
    params_: Variant,
    id_: Variant,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_request", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3423508980)
    }
    self := self
    method_ := method_
    params_ := params_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &params_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

jsonrpc_make_response :: proc "contextless" (
    self: Jsonrpc,
    result_: Variant,
    id_: Variant,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_response", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 5053918)
    }
    self := self
    result_ := result_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &result_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

jsonrpc_make_notification :: proc "contextless" (
    self: Jsonrpc,
    method_: String,
    params_: Variant,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_notification", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2949127017)
    }
    self := self
    method_ := method_
    params_ := params_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &params_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

jsonrpc_make_response_error :: proc "contextless" (
    self: Jsonrpc,
    code_: Int,
    message_: String,
    id_: Variant,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_response_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 928596297)
    }
    self := self
    code_ := code_
    message_ := message_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &code_,
        &message_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
jsonrpc_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("JSONRPC", true)
}

@(private = "file")
__class_name: String_Name