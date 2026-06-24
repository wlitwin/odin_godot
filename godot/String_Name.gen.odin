package godot

import __bindgen_gde "godot:gdext"


new_string_name :: proc {
    new_string_name_default,
    new_string_name_string_name,
    new_string_name_string,
    new_string_name_odin,
    new_string_name_cstring,
}

new_string_name_default :: proc "contextless" (
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.String_Name, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_string_name_string_name :: proc "contextless" (
    from_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.String_Name, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_string_name_string :: proc "contextless" (
    from_: String,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.String_Name, 2)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_string_name :: proc "contextless" (self: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.String_Name)
    }

    self := self
    __ptr(&self)
}

// members


string_name_casecmp_to :: proc "contextless" (
    self: ^String_Name,
    to_: String,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("casecmp_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2920860731)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_nocasecmp_to :: proc "contextless" (
    self: ^String_Name,
    to_: String,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("nocasecmp_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2920860731)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_naturalcasecmp_to :: proc "contextless" (
    self: ^String_Name,
    to_: String,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("naturalcasecmp_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2920860731)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_naturalnocasecmp_to :: proc "contextless" (
    self: ^String_Name,
    to_: String,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("naturalnocasecmp_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2920860731)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_filecasecmp_to :: proc "contextless" (
    self: ^String_Name,
    to_: String,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("filecasecmp_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2920860731)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_filenocasecmp_to :: proc "contextless" (
    self: ^String_Name,
    to_: String,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("filenocasecmp_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2920860731)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_length :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_substr :: proc "contextless" (
    self: ^String_Name,
    from_: Int,
    len_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("substr", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 787537301)
    }
    from_ := from_
    len_ := len_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &len_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_get_slice :: proc "contextless" (
    self: ^String_Name,
    delimiter_: String,
    slice_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slice", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3535100402)
    }
    delimiter_ := delimiter_
    slice_ := slice_
    args := []__bindgen_gde.TypePtr {
        &delimiter_,
        &slice_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_get_slicec :: proc "contextless" (
    self: ^String_Name,
    delimiter_: Int,
    slice_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slicec", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 787537301)
    }
    delimiter_ := delimiter_
    slice_ := slice_
    args := []__bindgen_gde.TypePtr {
        &delimiter_,
        &slice_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_get_slice_count :: proc "contextless" (
    self: ^String_Name,
    delimiter_: String,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slice_count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2920860731)
    }
    delimiter_ := delimiter_
    args := []__bindgen_gde.TypePtr {
        &delimiter_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_find :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1760645412)
    }
    what_ := what_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_findn :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("findn", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1760645412)
    }
    what_ := what_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_count :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    from_: Int,
    to_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2343087891)
    }
    what_ := what_
    from_ := from_
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &from_,
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_countn :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    from_: Int,
    to_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("countn", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2343087891)
    }
    what_ := what_
    from_ := from_
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &from_,
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_rfind :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rfind", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1760645412)
    }
    what_ := what_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_rfindn :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rfindn", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1760645412)
    }
    what_ := what_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_match :: proc "contextless" (
    self: ^String_Name,
    expr_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("match", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    expr_ := expr_
    args := []__bindgen_gde.TypePtr {
        &expr_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_matchn :: proc "contextless" (
    self: ^String_Name,
    expr_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("matchn", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    expr_ := expr_
    args := []__bindgen_gde.TypePtr {
        &expr_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_begins_with :: proc "contextless" (
    self: ^String_Name,
    text_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("begins_with", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_ends_with :: proc "contextless" (
    self: ^String_Name,
    text_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ends_with", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_subsequence_of :: proc "contextless" (
    self: ^String_Name,
    text_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_subsequence_of", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_subsequence_ofn :: proc "contextless" (
    self: ^String_Name,
    text_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_subsequence_ofn", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_bigrams :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bigrams", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 747180633)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_similarity :: proc "contextless" (
    self: ^String_Name,
    text_: String,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("similarity", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2697460964)
    }
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_format :: proc "contextless" (
    self: ^String_Name,
    values_: Variant,
    placeholder_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("format", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3212199029)
    }
    values_ := values_
    placeholder_ := placeholder_
    args := []__bindgen_gde.TypePtr {
        &values_,
        &placeholder_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_replace :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    forwhat_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("replace", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1340436205)
    }
    what_ := what_
    forwhat_ := forwhat_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &forwhat_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_replacen :: proc "contextless" (
    self: ^String_Name,
    what_: String,
    forwhat_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("replacen", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1340436205)
    }
    what_ := what_
    forwhat_ := forwhat_
    args := []__bindgen_gde.TypePtr {
        &what_,
        &forwhat_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_replace_char :: proc "contextless" (
    self: ^String_Name,
    key_: Int,
    with_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("replace_char", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 787537301)
    }
    key_ := key_
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &key_,
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_replace_chars :: proc "contextless" (
    self: ^String_Name,
    keys_: String,
    with_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("replace_chars", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3535100402)
    }
    keys_ := keys_
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &keys_,
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_remove_char :: proc "contextless" (
    self: ^String_Name,
    what_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_char", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2162347432)
    }
    what_ := what_
    args := []__bindgen_gde.TypePtr {
        &what_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_remove_chars :: proc "contextless" (
    self: ^String_Name,
    chars_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_chars", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3134094431)
    }
    chars_ := chars_
    args := []__bindgen_gde.TypePtr {
        &chars_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_repeat :: proc "contextless" (
    self: ^String_Name,
    count_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("repeat", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2162347432)
    }
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_reverse :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_insert :: proc "contextless" (
    self: ^String_Name,
    position_: Int,
    what_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 248737229)
    }
    position_ := position_
    what_ := what_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &what_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_erase :: proc "contextless" (
    self: ^String_Name,
    position_: Int,
    chars_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 787537301)
    }
    position_ := position_
    chars_ := chars_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &chars_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_capitalize :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("capitalize", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_camel_case :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_camel_case", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_pascal_case :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_pascal_case", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_snake_case :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_snake_case", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_kebab_case :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_kebab_case", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_split :: proc "contextless" (
    self: ^String_Name,
    delimiter_: String,
    allow_empty_: Bool,
    maxsplit_: Int,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("split", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1252735785)
    }
    delimiter_ := delimiter_
    allow_empty_ := allow_empty_
    maxsplit_ := maxsplit_
    args := []__bindgen_gde.TypePtr {
        &delimiter_,
        &allow_empty_,
        &maxsplit_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_rsplit :: proc "contextless" (
    self: ^String_Name,
    delimiter_: String,
    allow_empty_: Bool,
    maxsplit_: Int,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rsplit", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 1252735785)
    }
    delimiter_ := delimiter_
    allow_empty_ := allow_empty_
    maxsplit_ := maxsplit_
    args := []__bindgen_gde.TypePtr {
        &delimiter_,
        &allow_empty_,
        &maxsplit_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_split_floats :: proc "contextless" (
    self: ^String_Name,
    delimiter_: String,
    allow_empty_: Bool,
) -> (ret: Packed_Float64_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("split_floats", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2092079095)
    }
    delimiter_ := delimiter_
    allow_empty_ := allow_empty_
    args := []__bindgen_gde.TypePtr {
        &delimiter_,
        &allow_empty_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_join :: proc "contextless" (
    self: ^String_Name,
    parts_: Packed_String_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("join", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3595973238)
    }
    parts_ := parts_
    args := []__bindgen_gde.TypePtr {
        &parts_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_upper :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_upper", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_lower :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_lower", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_left :: proc "contextless" (
    self: ^String_Name,
    length_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("left", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2162347432)
    }
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_right :: proc "contextless" (
    self: ^String_Name,
    length_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("right", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2162347432)
    }
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_strip_edges :: proc "contextless" (
    self: ^String_Name,
    left_: Bool,
    right_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("strip_edges", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 907855311)
    }
    left_ := left_
    right_ := right_
    args := []__bindgen_gde.TypePtr {
        &left_,
        &right_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_strip_escapes :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("strip_escapes", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_lstrip :: proc "contextless" (
    self: ^String_Name,
    chars_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lstrip", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3134094431)
    }
    chars_ := chars_
    args := []__bindgen_gde.TypePtr {
        &chars_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_rstrip :: proc "contextless" (
    self: ^String_Name,
    chars_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rstrip", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3134094431)
    }
    chars_ := chars_
    args := []__bindgen_gde.TypePtr {
        &chars_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_get_extension :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_extension", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_get_basename :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_basename", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_path_join :: proc "contextless" (
    self: ^String_Name,
    path_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("path_join", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3134094431)
    }
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_unicode_at :: proc "contextless" (
    self: ^String_Name,
    at_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unicode_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 4103005248)
    }
    at_ := at_
    args := []__bindgen_gde.TypePtr {
        &at_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_indent :: proc "contextless" (
    self: ^String_Name,
    prefix_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("indent", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3134094431)
    }
    prefix_ := prefix_
    args := []__bindgen_gde.TypePtr {
        &prefix_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_dedent :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dedent", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_md5_text :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("md5_text", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_sha1_text :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sha1_text", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_sha256_text :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sha256_text", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_md5_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("md5_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_sha1_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sha1_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_sha256_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sha256_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_empty :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_contains :: proc "contextless" (
    self: ^String_Name,
    what_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("contains", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    what_ := what_
    args := []__bindgen_gde.TypePtr {
        &what_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_containsn :: proc "contextless" (
    self: ^String_Name,
    what_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("containsn", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2566493496)
    }
    what_ := what_
    args := []__bindgen_gde.TypePtr {
        &what_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_absolute_path :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_absolute_path", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_relative_path :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_relative_path", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_simplify_path :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("simplify_path", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_get_base_dir :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_base_dir", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_get_file :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_file", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_xml_escape :: proc "contextless" (
    self: ^String_Name,
    escape_quotes_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("xml_escape", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3429816538)
    }
    escape_quotes_ := escape_quotes_
    args := []__bindgen_gde.TypePtr {
        &escape_quotes_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_xml_unescape :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("xml_unescape", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_uri_encode :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uri_encode", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_uri_decode :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uri_decode", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_uri_file_decode :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uri_file_decode", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_c_escape :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("c_escape", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_c_unescape :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("c_unescape", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_json_escape :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("json_escape", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_validate_node_name :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("validate_node_name", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_validate_filename :: proc "contextless" (
    self: ^String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("validate_filename", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_ascii_identifier :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_ascii_identifier", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_unicode_identifier :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_unicode_identifier", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_identifier :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_identifier", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_int :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_int", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_float :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_float", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_hex_number :: proc "contextless" (
    self: ^String_Name,
    with_prefix_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_hex_number", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 593672999)
    }
    with_prefix_ := with_prefix_
    args := []__bindgen_gde.TypePtr {
        &with_prefix_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_html_color :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_html_color", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_ip_address :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_ip_address", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_is_valid_filename :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_filename", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_int :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_int", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_float :: proc "contextless" (
    self: ^String_Name,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_float", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_hex_to_int :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hex_to_int", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_bin_to_int :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bin_to_int", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_lpad :: proc "contextless" (
    self: ^String_Name,
    min_length_: Int,
    character_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lpad", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 248737229)
    }
    min_length_ := min_length_
    character_ := character_
    args := []__bindgen_gde.TypePtr {
        &min_length_,
        &character_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_rpad :: proc "contextless" (
    self: ^String_Name,
    min_length_: Int,
    character_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rpad", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 248737229)
    }
    min_length_ := min_length_
    character_ := character_
    args := []__bindgen_gde.TypePtr {
        &min_length_,
        &character_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_pad_decimals :: proc "contextless" (
    self: ^String_Name,
    digits_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pad_decimals", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2162347432)
    }
    digits_ := digits_
    args := []__bindgen_gde.TypePtr {
        &digits_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_pad_zeros :: proc "contextless" (
    self: ^String_Name,
    digits_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pad_zeros", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 2162347432)
    }
    digits_ := digits_
    args := []__bindgen_gde.TypePtr {
        &digits_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_trim_prefix :: proc "contextless" (
    self: ^String_Name,
    prefix_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("trim_prefix", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3134094431)
    }
    prefix_ := prefix_
    args := []__bindgen_gde.TypePtr {
        &prefix_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_trim_suffix :: proc "contextless" (
    self: ^String_Name,
    suffix_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("trim_suffix", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3134094431)
    }
    suffix_ := suffix_
    args := []__bindgen_gde.TypePtr {
        &suffix_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_ascii_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_ascii_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_utf8_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_utf8_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_utf16_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_utf16_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_utf32_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_utf32_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_wchar_buffer :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_wchar_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_to_multibyte_char_buffer :: proc "contextless" (
    self: ^String_Name,
    encoding_: String,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_multibyte_char_buffer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3055765187)
    }
    encoding_ := encoding_
    args := []__bindgen_gde.TypePtr {
        &encoding_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_hex_decode :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hex_decode", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
string_name_hash :: proc "contextless" (
    self: ^String_Name,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hash", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.String_Name, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

string_name_equal_variant :: proc "contextless" (self: String_Name, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .String_Name, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_equal_string :: proc "contextless" (self: String_Name, other: String) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .String_Name, .String)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_equal_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_equal :: proc {
    string_name_equal_variant,
    string_name_equal_string,
    string_name_equal_string_name,
}
string_name_not_equal_variant :: proc "contextless" (self: String_Name, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .String_Name, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_not_equal_string :: proc "contextless" (self: String_Name, other: String) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .String_Name, .String)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_not_equal_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_not_equal :: proc {
    string_name_not_equal_variant,
    string_name_not_equal_string,
    string_name_not_equal_string_name,
}
string_name_module_variant :: proc "contextless" (self: String_Name, other: Variant) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_bool :: proc "contextless" (self: String_Name, other: Bool) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Bool)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_int :: proc "contextless" (self: String_Name, other: Int) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_f64 :: proc "contextless" (self: String_Name, other: f64) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_string :: proc "contextless" (self: String_Name, other: String) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .String)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_vector2 :: proc "contextless" (self: String_Name, other: Vector2) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_vector2i :: proc "contextless" (self: String_Name, other: Vector2i) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_rect2 :: proc "contextless" (self: String_Name, other: Rect2) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Rect2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_rect2i :: proc "contextless" (self: String_Name, other: Rect2i) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Rect2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_vector3 :: proc "contextless" (self: String_Name, other: Vector3) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_vector3i :: proc "contextless" (self: String_Name, other: Vector3i) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_transform2d :: proc "contextless" (self: String_Name, other: Transform2d) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Transform2d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_vector4 :: proc "contextless" (self: String_Name, other: Vector4) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_vector4i :: proc "contextless" (self: String_Name, other: Vector4i) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_plane :: proc "contextless" (self: String_Name, other: Plane) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Plane)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_quaternion :: proc "contextless" (self: String_Name, other: Quaternion) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Quaternion)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_aabb :: proc "contextless" (self: String_Name, other: Aabb) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Aabb)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_basis :: proc "contextless" (self: String_Name, other: Basis) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Basis)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_transform3d :: proc "contextless" (self: String_Name, other: Transform3d) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Transform3d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_projection :: proc "contextless" (self: String_Name, other: Projection) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Projection)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_color :: proc "contextless" (self: String_Name, other: Color) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Color)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_node_path :: proc "contextless" (self: String_Name, other: Node_Path) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Node_Path)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_rid :: proc "contextless" (self: String_Name, other: Rid) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Rid)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_object :: proc "contextless" (self: String_Name, other: Object) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Object)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_callable :: proc "contextless" (self: String_Name, other: Callable) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Callable)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_signal :: proc "contextless" (self: String_Name, other: Signal) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Signal)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_dictionary :: proc "contextless" (self: String_Name, other: Dictionary) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_array :: proc "contextless" (self: String_Name, other: Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_byte_array :: proc "contextless" (self: String_Name, other: Packed_Byte_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Byte_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_int32_array :: proc "contextless" (self: String_Name, other: Packed_Int32_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Int32_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_int64_array :: proc "contextless" (self: String_Name, other: Packed_Int64_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Int64_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_float32_array :: proc "contextless" (self: String_Name, other: Packed_Float32_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Float32_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_float64_array :: proc "contextless" (self: String_Name, other: Packed_Float64_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Float64_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_string_array :: proc "contextless" (self: String_Name, other: Packed_String_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_String_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_vector2_array :: proc "contextless" (self: String_Name, other: Packed_Vector2_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Vector2_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_vector3_array :: proc "contextless" (self: String_Name, other: Packed_Vector3_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Vector3_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_color_array :: proc "contextless" (self: String_Name, other: Packed_Color_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Color_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_module_packed_vector4_array :: proc "contextless" (self: String_Name, other: Packed_Vector4_Array) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .String_Name, .Packed_Vector4_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_module :: proc {
    string_name_module_variant,
    string_name_module_bool,
    string_name_module_int,
    string_name_module_f64,
    string_name_module_string,
    string_name_module_vector2,
    string_name_module_vector2i,
    string_name_module_rect2,
    string_name_module_rect2i,
    string_name_module_vector3,
    string_name_module_vector3i,
    string_name_module_transform2d,
    string_name_module_vector4,
    string_name_module_vector4i,
    string_name_module_plane,
    string_name_module_quaternion,
    string_name_module_aabb,
    string_name_module_basis,
    string_name_module_transform3d,
    string_name_module_projection,
    string_name_module_color,
    string_name_module_string_name,
    string_name_module_node_path,
    string_name_module_rid,
    string_name_module_object,
    string_name_module_callable,
    string_name_module_signal,
    string_name_module_dictionary,
    string_name_module_array,
    string_name_module_packed_byte_array,
    string_name_module_packed_int32_array,
    string_name_module_packed_int64_array,
    string_name_module_packed_float32_array,
    string_name_module_packed_float64_array,
    string_name_module_packed_string_array,
    string_name_module_packed_vector2_array,
    string_name_module_packed_vector3_array,
    string_name_module_packed_color_array,
    string_name_module_packed_vector4_array,
}
string_name_not_default :: proc "contextless" (self: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .String_Name, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

string_name_not :: proc {
    string_name_not_default,
}
string_name_add_string :: proc "contextless" (self: String_Name, other: String) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .String_Name, .String)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_add_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_add :: proc {
    string_name_add_string,
    string_name_add_string_name,
}
string_name_in_string :: proc "contextless" (self: String_Name, other: String) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .String_Name, .String)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_in_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_in_object :: proc "contextless" (self: String_Name, other: Object) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .String_Name, .Object)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_in_dictionary :: proc "contextless" (self: String_Name, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .String_Name, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_in_array :: proc "contextless" (self: String_Name, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .String_Name, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
string_name_in_packed_string_array :: proc "contextless" (self: String_Name, other: Packed_String_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .String_Name, .Packed_String_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_in :: proc {
    string_name_in_string,
    string_name_in_string_name,
    string_name_in_object,
    string_name_in_dictionary,
    string_name_in_array,
    string_name_in_packed_string_array,
}
string_name_less_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_less :: proc {
    string_name_less_string_name,
}
string_name_less_equal_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_less_equal :: proc {
    string_name_less_equal_string_name,
}
string_name_greater_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_greater :: proc {
    string_name_greater_string_name,
}
string_name_greater_equal_string_name :: proc "contextless" (self: String_Name, other: String_Name) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .String_Name, .String_Name)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

string_name_greater_equal :: proc {
    string_name_greater_equal_string_name,
}

