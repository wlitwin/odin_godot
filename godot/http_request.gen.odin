package godot

import __bindgen_gde "godot:gdext"

Http_Request_Constants :: enum {
}
Http_Request_Result :: enum int {
    Result_Success = 0,
    Result_Chunked_Body_Size_Mismatch = 1,
    Result_Cant_Connect = 2,
    Result_Cant_Resolve = 3,
    Result_Connection_Error = 4,
    Result_Tls_Handshake_Error = 5,
    Result_No_Response = 6,
    Result_Body_Size_Limit_Exceeded = 7,
    Result_Body_Decompress_Failed = 8,
    Result_Request_Failed = 9,
    Result_Download_File_Cant_Open = 10,
    Result_Download_File_Write_Error = 11,
    Result_Redirect_Limit_Reached = 12,
    Result_Timeout = 13,
}



http_request_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

http_request_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_http_request :: proc "contextless" () -> Http_Request {
    return cast(Http_Request)__bindgen_gde.classdb_construct_object(http_request_name_ref())
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

http_request_request :: proc "contextless" (
    self: Http_Request,
    url_: String,
    custom_headers_: Packed_String_Array,
    method_: Http_Client_Method,
    request_data_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3215244323)
    }
    self := self
    url_ := url_
    custom_headers_ := custom_headers_
    method_ := method_
    request_data_ := request_data_
    args := []__bindgen_gde.TypePtr {
        &url_,
        &custom_headers_,
        &method_,
        &request_data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_request_raw :: proc "contextless" (
    self: Http_Request,
    url_: String,
    custom_headers_: Packed_String_Array,
    method_: Http_Client_Method,
    request_data_raw_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request_raw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2714829993)
    }
    self := self
    url_ := url_
    custom_headers_ := custom_headers_
    method_ := method_
    request_data_raw_ := request_data_raw_
    args := []__bindgen_gde.TypePtr {
        &url_,
        &custom_headers_,
        &method_,
        &request_data_raw_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_cancel_request :: proc "contextless" (
    self: Http_Request,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cancel_request", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_set_tls_options :: proc "contextless" (
    self: Http_Request,
    client_options_: Tls_Options,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tls_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2210231844)
    }
    self := self
    client_options_ := client_options_
    args := []__bindgen_gde.TypePtr {
        &client_options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_get_http_client_status :: proc "contextless" (
    self: Http_Request,
) -> (ret: Http_Client_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_http_client_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1426656811)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_use_threads :: proc "contextless" (
    self: Http_Request,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_threads", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_is_using_threads :: proc "contextless" (
    self: Http_Request,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_threads", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_accept_gzip :: proc "contextless" (
    self: Http_Request,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_accept_gzip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_is_accepting_gzip :: proc "contextless" (
    self: Http_Request,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_accepting_gzip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_body_size_limit :: proc "contextless" (
    self: Http_Request,
    bytes_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_body_size_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    bytes_ := bytes_
    args := []__bindgen_gde.TypePtr {
        &bytes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_get_body_size_limit :: proc "contextless" (
    self: Http_Request,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_body_size_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_max_redirects :: proc "contextless" (
    self: Http_Request,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_redirects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_get_max_redirects :: proc "contextless" (
    self: Http_Request,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_redirects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_download_file :: proc "contextless" (
    self: Http_Request,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_download_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_get_download_file :: proc "contextless" (
    self: Http_Request,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_download_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_get_downloaded_bytes :: proc "contextless" (
    self: Http_Request,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_downloaded_bytes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_get_body_size :: proc "contextless" (
    self: Http_Request,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_body_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_timeout :: proc "contextless" (
    self: Http_Request,
    timeout_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_timeout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    timeout_ := timeout_
    args := []__bindgen_gde.TypePtr {
        &timeout_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_get_timeout :: proc "contextless" (
    self: Http_Request,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_timeout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_download_chunk_size :: proc "contextless" (
    self: Http_Request,
    chunk_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_download_chunk_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    chunk_size_ := chunk_size_
    args := []__bindgen_gde.TypePtr {
        &chunk_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

http_request_get_download_chunk_size :: proc "contextless" (
    self: Http_Request,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_download_chunk_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

http_request_set_http_proxy :: proc "contextless" (
    self: Http_Request,
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

http_request_set_https_proxy :: proc "contextless" (
    self: Http_Request,
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


// properties
http_request_get_use_threads :: proc "contextless" (self: Http_Request) -> Bool {
    return http_request_is_using_threads(self)
}
http_request_get_accept_gzip :: proc "contextless" (self: Http_Request) -> Bool {
    return http_request_is_accepting_gzip(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
http_request_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("HTTPRequest", true)
}

@(private = "file")
__class_name: String_Name