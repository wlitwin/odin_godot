package godot

import __bindgen_gde "godot:gdext"

Marshalls_Constants :: enum {
}



marshalls_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

marshalls_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_marshalls :: proc "contextless" () -> Marshalls {
    return __bindgen_gde.classdb_construct_object(marshalls_name_ref())
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

marshalls_variant_to_base64 :: proc "contextless" (
    self: Marshalls,
    variant_: Variant,
    full_objects_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("variant_to_base64", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3876248563)
    }
    self := self
    variant_ := variant_
    full_objects_ := full_objects_
    args := []__bindgen_gde.TypePtr {
        &variant_,
        &full_objects_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

marshalls_base64_to_variant :: proc "contextless" (
    self: Marshalls,
    base64_str_: String,
    allow_objects_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("base64_to_variant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218087648)
    }
    self := self
    base64_str_ := base64_str_
    allow_objects_ := allow_objects_
    args := []__bindgen_gde.TypePtr {
        &base64_str_,
        &allow_objects_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

marshalls_raw_to_base64 :: proc "contextless" (
    self: Marshalls,
    array_: Packed_Byte_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("raw_to_base64", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3999417757)
    }
    self := self
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

marshalls_base64_to_raw :: proc "contextless" (
    self: Marshalls,
    base64_str_: String,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("base64_to_raw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659035735)
    }
    self := self
    base64_str_ := base64_str_
    args := []__bindgen_gde.TypePtr {
        &base64_str_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

marshalls_utf8_to_base64 :: proc "contextless" (
    self: Marshalls,
    utf8_str_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("utf8_to_base64", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1703090593)
    }
    self := self
    utf8_str_ := utf8_str_
    args := []__bindgen_gde.TypePtr {
        &utf8_str_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

marshalls_base64_to_utf8 :: proc "contextless" (
    self: Marshalls,
    base64_str_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("base64_to_utf8", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1703090593)
    }
    self := self
    base64_str_ := base64_str_
    args := []__bindgen_gde.TypePtr {
        &base64_str_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
marshalls_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Marshalls", true)
}

@(private = "file")
__class_name: String_Name