package godot

import __bindgen_gde "godot:gdext"

Translation_Constants :: enum {
}



translation_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

translation_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_translation :: proc "contextless" () -> Translation {
    return cast(Translation)__bindgen_gde.classdb_construct_object(translation_name_ref())
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

translation__get_plural_message :: proc "contextless" (
    self: Translation,
    src_message_: String_Name,
    src_plural_message_: String_Name,
    n_: Int,
    context_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_plural_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1970324172)
    }
    self := self
    src_message_ := src_message_
    src_plural_message_ := src_plural_message_
    n_ := n_
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &src_message_,
        &src_plural_message_,
        &n_,
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation__get_message :: proc "contextless" (
    self: Translation,
    src_message_: String_Name,
    context_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3639719779)
    }
    self := self
    src_message_ := src_message_
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &src_message_,
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation_set_locale :: proc "contextless" (
    self: Translation,
    locale_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_locale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    locale_ := locale_
    args := []__bindgen_gde.TypePtr {
        &locale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

translation_get_locale :: proc "contextless" (
    self: Translation,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_locale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation_add_message :: proc "contextless" (
    self: Translation,
    src_message_: String_Name,
    xlated_message_: String_Name,
    context_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3898530326)
    }
    self := self
    src_message_ := src_message_
    xlated_message_ := xlated_message_
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &src_message_,
        &xlated_message_,
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

translation_add_plural_message :: proc "contextless" (
    self: Translation,
    src_message_: String_Name,
    xlated_messages_: Packed_String_Array,
    context_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_plural_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2356982266)
    }
    self := self
    src_message_ := src_message_
    xlated_messages_ := xlated_messages_
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &src_message_,
        &xlated_messages_,
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

translation_get_message :: proc "contextless" (
    self: Translation,
    src_message_: String_Name,
    context_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1829228469)
    }
    self := self
    src_message_ := src_message_
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &src_message_,
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation_get_plural_message :: proc "contextless" (
    self: Translation,
    src_message_: String_Name,
    src_plural_message_: String_Name,
    n_: Int,
    context_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_plural_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 229954002)
    }
    self := self
    src_message_ := src_message_
    src_plural_message_ := src_plural_message_
    n_ := n_
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &src_message_,
        &src_plural_message_,
        &n_,
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation_erase_message :: proc "contextless" (
    self: Translation,
    src_message_: String_Name,
    context_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3959009644)
    }
    self := self
    src_message_ := src_message_
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &src_message_,
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

translation_get_message_list :: proc "contextless" (
    self: Translation,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_message_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation_get_translated_message_list :: proc "contextless" (
    self: Translation,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_translated_message_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation_get_message_count :: proc "contextless" (
    self: Translation,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_message_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

translation_set_plural_rules_override :: proc "contextless" (
    self: Translation,
    rules_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_plural_rules_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    rules_ := rules_
    args := []__bindgen_gde.TypePtr {
        &rules_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

translation_get_plural_rules_override :: proc "contextless" (
    self: Translation,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_plural_rules_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
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
translation_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Translation", true)
}

@(private = "file")
__class_name: String_Name