package godot

import __bindgen_gde "godot:gdext"


new_dictionary :: proc {
    new_dictionary_default,
    new_dictionary_dictionary,
    new_dictionary_dictionary_int_string_name_variant_int_string_name_variant,
}

new_dictionary_default :: proc "contextless" (
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Dictionary, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_dictionary_dictionary :: proc "contextless" (
    from_: Dictionary,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Dictionary, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_dictionary_dictionary_int_string_name_variant_int_string_name_variant :: proc "contextless" (
    base_: Dictionary,
    key_type_: Int,
    key_class_name_: String_Name,
    key_script_: Variant,
    value_type_: Int,
    value_class_name_: String_Name,
    value_script_: Variant,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Dictionary, 2)
    }
    base_ := base_
    key_type_ := key_type_
    key_class_name_ := key_class_name_
    key_script_ := key_script_
    value_type_ := value_type_
    value_class_name_ := value_class_name_
    value_script_ := value_script_
    args := []__bindgen_gde.TypePtr {
        &base_,
        &key_type_,
        &key_class_name_,
        &key_script_,
        &value_type_,
        &value_class_name_,
        &value_script_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_dictionary :: proc "contextless" (self: Dictionary) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Dictionary)
    }

    self := self
    __ptr(&self)
}

// members


dictionary_size :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_is_empty :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_clear :: proc "contextless" (
    self: ^Dictionary,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
dictionary_assign :: proc "contextless" (
    self: ^Dictionary,
    dictionary_: Dictionary,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("assign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3642266950)
    }
    dictionary_ := dictionary_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
dictionary_sort :: proc "contextless" (
    self: ^Dictionary,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sort", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
dictionary_merge :: proc "contextless" (
    self: ^Dictionary,
    dictionary_: Dictionary,
    overwrite_: Bool,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 2079548978)
    }
    dictionary_ := dictionary_
    overwrite_ := overwrite_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
        &overwrite_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
dictionary_merged :: proc "contextless" (
    self: ^Dictionary,
    dictionary_: Dictionary,
    overwrite_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merged", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 2271165639)
    }
    dictionary_ := dictionary_
    overwrite_ := overwrite_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
        &overwrite_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_has :: proc "contextless" (
    self: ^Dictionary,
    key_: Variant,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3680194679)
    }
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &key_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_has_all :: proc "contextless" (
    self: ^Dictionary,
    keys_: Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_all", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 2988181878)
    }
    keys_ := keys_
    args := []__bindgen_gde.TypePtr {
        &keys_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_find_key :: proc "contextless" (
    self: ^Dictionary,
    value_: Variant,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_key", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1988825835)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_erase :: proc "contextless" (
    self: ^Dictionary,
    key_: Variant,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1776646889)
    }
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &key_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_hash :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hash", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_keys :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keys", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 4144163970)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_values :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("values", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 4144163970)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_duplicate :: proc "contextless" (
    self: ^Dictionary,
    deep_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 830099069)
    }
    deep_ := deep_
    args := []__bindgen_gde.TypePtr {
        &deep_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_duplicate_deep :: proc "contextless" (
    self: ^Dictionary,
    deep_subresources_mode_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate_deep", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 2160600714)
    }
    deep_subresources_mode_ := deep_subresources_mode_
    args := []__bindgen_gde.TypePtr {
        &deep_subresources_mode_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get :: proc "contextless" (
    self: ^Dictionary,
    key_: Variant,
    default_: Variant,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 2205440559)
    }
    key_ := key_
    default_ := default_
    args := []__bindgen_gde.TypePtr {
        &key_,
        &default_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get_or_add :: proc "contextless" (
    self: ^Dictionary,
    key_: Variant,
    default_: Variant,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_or_add", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1052551076)
    }
    key_ := key_
    default_ := default_
    args := []__bindgen_gde.TypePtr {
        &key_,
        &default_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_set :: proc "contextless" (
    self: ^Dictionary,
    key_: Variant,
    value_: Variant,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 2175348267)
    }
    key_ := key_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &key_,
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_is_typed :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_typed", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_is_typed_key :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_typed_key", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_is_typed_value :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_typed_value", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_is_same_typed :: proc "contextless" (
    self: ^Dictionary,
    dictionary_: Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_same_typed", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3471775634)
    }
    dictionary_ := dictionary_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_is_same_typed_key :: proc "contextless" (
    self: ^Dictionary,
    dictionary_: Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_same_typed_key", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3471775634)
    }
    dictionary_ := dictionary_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_is_same_typed_value :: proc "contextless" (
    self: ^Dictionary,
    dictionary_: Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_same_typed_value", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3471775634)
    }
    dictionary_ := dictionary_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get_typed_key_builtin :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_key_builtin", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get_typed_value_builtin :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_value_builtin", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get_typed_key_class_name :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_key_class_name", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1825232092)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get_typed_value_class_name :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_value_class_name", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1825232092)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get_typed_key_script :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_key_script", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_get_typed_value_script :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_value_script", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_make_read_only :: proc "contextless" (
    self: ^Dictionary,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_read_only", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
dictionary_is_read_only :: proc "contextless" (
    self: ^Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_read_only", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
dictionary_recursive_equal :: proc "contextless" (
    self: ^Dictionary,
    dictionary_: Dictionary,
    recursion_count_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("recursive_equal", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Dictionary, &_gde_name, 1404404751)
    }
    dictionary_ := dictionary_
    recursion_count_ := recursion_count_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
        &recursion_count_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

dictionary_equal_variant :: proc "contextless" (self: Dictionary, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Dictionary, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
dictionary_equal_dictionary :: proc "contextless" (self: Dictionary, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Dictionary, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

dictionary_equal :: proc {
    dictionary_equal_variant,
    dictionary_equal_dictionary,
}
dictionary_not_equal_variant :: proc "contextless" (self: Dictionary, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Dictionary, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
dictionary_not_equal_dictionary :: proc "contextless" (self: Dictionary, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Dictionary, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

dictionary_not_equal :: proc {
    dictionary_not_equal_variant,
    dictionary_not_equal_dictionary,
}
dictionary_not_default :: proc "contextless" (self: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Dictionary, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

dictionary_not :: proc {
    dictionary_not_default,
}
dictionary_in_dictionary :: proc "contextless" (self: Dictionary, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Dictionary, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
dictionary_in_array :: proc "contextless" (self: Dictionary, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Dictionary, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

dictionary_in :: proc {
    dictionary_in_dictionary,
    dictionary_in_array,
}

