package godot

import __bindgen_gde "godot:gdext"

Crypto_Key_Constants :: enum {
}



crypto_key_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

crypto_key_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_crypto_key :: proc "contextless" () -> Crypto_Key {
    return cast(Crypto_Key)__bindgen_gde.classdb_construct_object(crypto_key_name_ref())
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

crypto_key_save :: proc "contextless" (
    self: Crypto_Key,
    path_: String,
    public_only_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 885841341)
    }
    self := self
    path_ := path_
    public_only_ := public_only_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &public_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_key_load :: proc "contextless" (
    self: Crypto_Key,
    path_: String,
    public_only_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 885841341)
    }
    self := self
    path_ := path_
    public_only_ := public_only_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &public_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_key_is_public_only :: proc "contextless" (
    self: Crypto_Key,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_public_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_key_save_to_string :: proc "contextless" (
    self: Crypto_Key,
    public_only_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_to_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 32795936)
    }
    self := self
    public_only_ := public_only_
    args := []__bindgen_gde.TypePtr {
        &public_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

crypto_key_load_from_string :: proc "contextless" (
    self: Crypto_Key,
    string_key_: String,
    public_only_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_from_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 885841341)
    }
    self := self
    string_key_ := string_key_
    public_only_ := public_only_
    args := []__bindgen_gde.TypePtr {
        &string_key_,
        &public_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
crypto_key_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CryptoKey", true)
}

@(private = "file")
__class_name: String_Name