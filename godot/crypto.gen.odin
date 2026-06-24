package godot

import __bindgen_gde "godot:gdext"

Crypto_Constants :: enum {
}



crypto_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

crypto_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_crypto :: proc "contextless" () -> Crypto {
    return cast(Crypto)__bindgen_gde.classdb_construct_object(crypto_name_ref())
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

crypto_generate_random_bytes :: proc "contextless" (
    self: Crypto,
    size_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_random_bytes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 47165747)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_generate_rsa :: proc "contextless" (
    self: Crypto,
    size_: Int,
) -> (ret: Crypto_Key) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_rsa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1237515462)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_generate_self_signed_certificate :: proc "contextless" (
    self: Crypto,
    key_: Crypto_Key,
    issuer_name_: String,
    not_before_: String,
    not_after_: String,
) -> (ret: X509_Certificate) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_self_signed_certificate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 492266173)
    }
    self := self
    key_ := key_
    issuer_name_ := issuer_name_
    not_before_ := not_before_
    not_after_ := not_after_
    args := []__bindgen_gde.TypePtr {
        &key_,
        &issuer_name_,
        &not_before_,
        &not_after_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_sign :: proc "contextless" (
    self: Crypto,
    hash_type_: Hashing_Context_Hash_Type,
    hash_: Packed_Byte_Array,
    key_: Crypto_Key,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sign", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1673662703)
    }
    self := self
    hash_type_ := hash_type_
    hash_ := hash_
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &hash_type_,
        &hash_,
        &key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_verify :: proc "contextless" (
    self: Crypto,
    hash_type_: Hashing_Context_Hash_Type,
    hash_: Packed_Byte_Array,
    signature_: Packed_Byte_Array,
    key_: Crypto_Key,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("verify", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2805902225)
    }
    self := self
    hash_type_ := hash_type_
    hash_ := hash_
    signature_ := signature_
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &hash_type_,
        &hash_,
        &signature_,
        &key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_encrypt :: proc "contextless" (
    self: Crypto,
    key_: Crypto_Key,
    plaintext_: Packed_Byte_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encrypt", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2361793670)
    }
    self := self
    key_ := key_
    plaintext_ := plaintext_
    args := []__bindgen_gde.TypePtr {
        &key_,
        &plaintext_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_decrypt :: proc "contextless" (
    self: Crypto,
    key_: Crypto_Key,
    ciphertext_: Packed_Byte_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decrypt", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2361793670)
    }
    self := self
    key_ := key_
    ciphertext_ := ciphertext_
    args := []__bindgen_gde.TypePtr {
        &key_,
        &ciphertext_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_hmac_digest :: proc "contextless" (
    self: Crypto,
    hash_type_: Hashing_Context_Hash_Type,
    key_: Packed_Byte_Array,
    msg_: Packed_Byte_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hmac_digest", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2368951203)
    }
    self := self
    hash_type_ := hash_type_
    key_ := key_
    msg_ := msg_
    args := []__bindgen_gde.TypePtr {
        &hash_type_,
        &key_,
        &msg_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_constant_time_compare :: proc "contextless" (
    self: Crypto,
    trusted_: Packed_Byte_Array,
    received_: Packed_Byte_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("constant_time_compare", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1024142237)
    }
    self := self
    trusted_ := trusted_
    received_ := received_
    args := []__bindgen_gde.TypePtr {
        &trusted_,
        &received_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
crypto_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Crypto", true)
}

@(private = "file")
__class_name: String_Name