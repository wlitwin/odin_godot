package godot

import __bindgen_gde "godot:gdext"

Http_Client_Constants :: enum {
}
Http_Client_Method :: enum int {
    Method_Get = 0,
    Method_Head = 1,
    Method_Post = 2,
    Method_Put = 3,
    Method_Delete = 4,
    Method_Options = 5,
    Method_Trace = 6,
    Method_Connect = 7,
    Method_Patch = 8,
    Method_Max = 9,
}
Http_Client_Status :: enum int {
    Status_Disconnected = 0,
    Status_Resolving = 1,
    Status_Cant_Resolve = 2,
    Status_Connecting = 3,
    Status_Cant_Connect = 4,
    Status_Connected = 5,
    Status_Requesting = 6,
    Status_Body = 7,
    Status_Connection_Error = 8,
    Status_Tls_Handshake_Error = 9,
}
Http_Client_Response_Code :: enum int {
    Response_Continue = 100,
    Response_Switching_Protocols = 101,
    Response_Processing = 102,
    Response_Ok = 200,
    Response_Created = 201,
    Response_Accepted = 202,
    Response_Non_Authoritative_Information = 203,
    Response_No_Content = 204,
    Response_Reset_Content = 205,
    Response_Partial_Content = 206,
    Response_Multi_Status = 207,
    Response_Already_Reported = 208,
    Response_Im_Used = 226,
    Response_Multiple_Choices = 300,
    Response_Moved_Permanently = 301,
    Response_Found = 302,
    Response_See_Other = 303,
    Response_Not_Modified = 304,
    Response_Use_Proxy = 305,
    Response_Switch_Proxy = 306,
    Response_Temporary_Redirect = 307,
    Response_Permanent_Redirect = 308,
    Response_Bad_Request = 400,
    Response_Unauthorized = 401,
    Response_Payment_Required = 402,
    Response_Forbidden = 403,
    Response_Not_Found = 404,
    Response_Method_Not_Allowed = 405,
    Response_Not_Acceptable = 406,
    Response_Proxy_Authentication_Required = 407,
    Response_Request_Timeout = 408,
    Response_Conflict = 409,
    Response_Gone = 410,
    Response_Length_Required = 411,
    Response_Precondition_Failed = 412,
    Response_Request_Entity_Too_Large = 413,
    Response_Request_Uri_Too_Long = 414,
    Response_Unsupported_Media_Type = 415,
    Response_Requested_Range_Not_Satisfiable = 416,
    Response_Expectation_Failed = 417,
    Response_Im_A_Teapot = 418,
    Response_Misdirected_Request = 421,
    Response_Unprocessable_Entity = 422,
    Response_Locked = 423,
    Response_Failed_Dependency = 424,
    Response_Upgrade_Required = 426,
    Response_Precondition_Required = 428,
    Response_Too_Many_Requests = 429,
    Response_Request_Header_Fields_Too_Large = 431,
    Response_Unavailable_For_Legal_Reasons = 451,
    Response_Internal_Server_Error = 500,
    Response_Not_Implemented = 501,
    Response_Bad_Gateway = 502,
    Response_Service_Unavailable = 503,
    Response_Gateway_Timeout = 504,
    Response_Http_Version_Not_Supported = 505,
    Response_Variant_Also_Negotiates = 506,
    Response_Insufficient_Storage = 507,
    Response_Loop_Detected = 508,
    Response_Not_Extended = 510,
    Response_Network_Auth_Required = 511,
}



http_client_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

http_client_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_http_client :: proc "contextless" () -> Http_Client {
    return cast(Http_Client)__bindgen_gde.classdb_construct_object(http_client_name_ref())
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

http_client_connect_to_host :: proc "contextless" (
    self: Http_Client,
    host_: String,
    port_: Int,
    tls_options_: Tls_Options,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_to_host", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 504540374)
    }
    self := self
    host_ := host_
    port_ := port_
    tls_options_ := tls_options_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &port_,
        &tls_options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_set_connection :: proc "contextless" (
    self: Http_Client,
    connection_: Stream_Peer,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_connection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3281897016)
    }
    self := self
    connection_ := connection_
    args := []__bindgen_gde.TypePtr {
        &connection_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_client_get_connection :: proc "contextless" (
    self: Http_Client,
) -> (ret: Stream_Peer) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2741655269)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_request_raw :: proc "contextless" (
    self: Http_Client,
    method_: Http_Client_Method,
    url_: String,
    headers_: Packed_String_Array,
    body_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request_raw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 540161961)
    }
    self := self
    method_ := method_
    url_ := url_
    headers_ := headers_
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &url_,
        &headers_,
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_request :: proc "contextless" (
    self: Http_Client,
    method_: Http_Client_Method,
    url_: String,
    headers_: Packed_String_Array,
    body_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3778990155)
    }
    self := self
    method_ := method_
    url_ := url_
    headers_ := headers_
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &url_,
        &headers_,
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_close :: proc "contextless" (
    self: Http_Client,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("close", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_client_has_response :: proc "contextless" (
    self: Http_Client,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_response", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_is_response_chunked :: proc "contextless" (
    self: Http_Client,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_response_chunked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_get_response_code :: proc "contextless" (
    self: Http_Client,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_response_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_get_response_headers :: proc "contextless" (
    self: Http_Client,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_response_headers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_get_response_headers_as_dictionary :: proc "contextless" (
    self: Http_Client,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_response_headers_as_dictionary", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2382534195)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_get_response_body_length :: proc "contextless" (
    self: Http_Client,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_response_body_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_read_response_body_chunk :: proc "contextless" (
    self: Http_Client,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("read_response_body_chunk", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2115431945)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_set_read_chunk_size :: proc "contextless" (
    self: Http_Client,
    bytes_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_read_chunk_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    bytes_ := bytes_
    args := []__bindgen_gde.TypePtr {
        &bytes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_client_get_read_chunk_size :: proc "contextless" (
    self: Http_Client,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_read_chunk_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_set_blocking_mode :: proc "contextless" (
    self: Http_Client,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blocking_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_client_is_blocking_mode_enabled :: proc "contextless" (
    self: Http_Client,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_blocking_mode_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_get_status :: proc "contextless" (
    self: Http_Client,
) -> (ret: Http_Client_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1426656811)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_poll :: proc "contextless" (
    self: Http_Client,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("poll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_client_set_http_proxy :: proc "contextless" (
    self: Http_Client,
    host_: String,
    port_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_http_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2956805083)
    }
    self := self
    host_ := host_
    port_ := port_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_client_set_https_proxy :: proc "contextless" (
    self: Http_Client,
    host_: String,
    port_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_https_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2956805083)
    }
    self := self
    host_ := host_
    port_ := port_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_client_query_string_from_dict :: proc "contextless" (
    self: Http_Client,
    fields_: Dictionary,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("query_string_from_dict", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2538086567)
    }
    self := self
    fields_ := fields_
    args := []__bindgen_gde.TypePtr {
        &fields_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
http_client_get_blocking_mode_enabled :: proc "contextless" (self: Http_Client) -> Bool {
    return http_client_is_blocking_mode_enabled(self)
}
http_client_set_blocking_mode_enabled :: proc "contextless" (self: Http_Client, value: Bool) {
    http_client_set_blocking_mode(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
http_client_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("HTTPClient", true)
}

@(private = "file")
__class_name: String_Name