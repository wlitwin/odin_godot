package godot

import __bindgen_gde "godot:gdext"

Aes_Context_Constants :: enum {
}
Aes_Context_Mode :: enum int {
    Mode_Ecb_Encrypt = 0,
    Mode_Ecb_Decrypt = 1,
    Mode_Cbc_Encrypt = 2,
    Mode_Cbc_Decrypt = 3,
    Mode_Max = 4,
}



aes_context_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

aes_context_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_aes_context :: proc "contextless" () -> Aes_Context {
    return cast(Aes_Context)__bindgen_gde.classdb_construct_object(aes_context_name_ref())
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

aes_context_start :: proc "contextless" (
    self: Aes_Context,
    mode_: Aes_Context_Mode,
    key_: Packed_Byte_Array,
    iv_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3122411423)
    }
    self := self
    mode_ := mode_
    key_ := key_
    iv_ := iv_
    args := []__bindgen_gde.TypePtr {
        &mode_,
        &key_,
        &iv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

aes_context_update :: proc "contextless" (
    self: Aes_Context,
    src_: Packed_Byte_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 527836100)
    }
    self := self
    src_ := src_
    args := []__bindgen_gde.TypePtr {
        &src_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

aes_context_get_iv_state :: proc "contextless" (
    self: Aes_Context,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_iv_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2115431945)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

aes_context_finish :: proc "contextless" (
    self: Aes_Context,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("finish", true)
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
aes_context_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AESContext", true)
}

@(private = "file")
__class_name: String_Name