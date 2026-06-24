package godot

import __bindgen_gde "godot:gdext"


new_packed_float32_array :: proc {
    new_packed_float32_array_default,
    new_packed_float32_array_packed_float32_array,
    new_packed_float32_array_array,
}

new_packed_float32_array_default :: proc "contextless" (
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Float32_Array, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_packed_float32_array_packed_float32_array :: proc "contextless" (
    from_: Packed_Float32_Array,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Float32_Array, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_packed_float32_array_array :: proc "contextless" (
    from_: Array,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Float32_Array, 2)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_packed_float32_array :: proc "contextless" (self: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Packed_Float32_Array)
    }

    self := self
    __ptr(&self)
}

// members


packed_float32_array_get :: proc "contextless" (
    self: ^Packed_Float32_Array,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1401583798)
    }
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_set :: proc "contextless" (
    self: ^Packed_Float32_Array,
    index_: Int,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1113000516)
    }
    index_ := index_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_float32_array_size :: proc "contextless" (
    self: ^Packed_Float32_Array,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_is_empty :: proc "contextless" (
    self: ^Packed_Float32_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_push_back :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_back", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 4094791666)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_append :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 4094791666)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_append_array :: proc "contextless" (
    self: ^Packed_Float32_Array,
    array_: Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 2981316639)
    }
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_float32_array_remove_at :: proc "contextless" (
    self: ^Packed_Float32_Array,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 2823966027)
    }
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_float32_array_insert :: proc "contextless" (
    self: ^Packed_Float32_Array,
    at_index_: Int,
    value_: f64,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1379903876)
    }
    at_index_ := at_index_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &at_index_,
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_fill :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 833936903)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_float32_array_resize :: proc "contextless" (
    self: ^Packed_Float32_Array,
    new_size_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resize", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 848867239)
    }
    new_size_ := new_size_
    args := []__bindgen_gde.TypePtr {
        &new_size_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_clear :: proc "contextless" (
    self: ^Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_float32_array_has :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1296369134)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_reverse :: proc "contextless" (
    self: ^Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_float32_array_slice :: proc "contextless" (
    self: ^Packed_Float32_Array,
    begin_: Int,
    end_: Int,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slice", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1418229160)
    }
    begin_ := begin_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &begin_,
        &end_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_to_byte_array :: proc "contextless" (
    self: ^Packed_Float32_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_byte_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_sort :: proc "contextless" (
    self: ^Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sort", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_float32_array_bsearch :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
    before_: Bool,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bsearch", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1175118842)
    }
    value_ := value_
    before_ := before_
    args := []__bindgen_gde.TypePtr {
        &value_,
        &before_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_duplicate :: proc "contextless" (
    self: ^Packed_Float32_Array,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 3575107827)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_find :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1343150241)
    }
    value_ := value_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &value_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_rfind :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rfind", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 1343150241)
    }
    value_ := value_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &value_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_count :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 2859915090)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_float32_array_erase :: proc "contextless" (
    self: ^Packed_Float32_Array,
    value_: f64,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Float32_Array, &_gde_name, 4094791666)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

packed_float32_array_equal_variant :: proc "contextless" (self: Packed_Float32_Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Packed_Float32_Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_float32_array_equal_packed_float32_array :: proc "contextless" (self: Packed_Float32_Array, other: Packed_Float32_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Packed_Float32_Array, .Packed_Float32_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_float32_array_equal :: proc {
    packed_float32_array_equal_variant,
    packed_float32_array_equal_packed_float32_array,
}
packed_float32_array_not_equal_variant :: proc "contextless" (self: Packed_Float32_Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Packed_Float32_Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_float32_array_not_equal_packed_float32_array :: proc "contextless" (self: Packed_Float32_Array, other: Packed_Float32_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Packed_Float32_Array, .Packed_Float32_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_float32_array_not_equal :: proc {
    packed_float32_array_not_equal_variant,
    packed_float32_array_not_equal_packed_float32_array,
}
packed_float32_array_not_default :: proc "contextless" (self: Packed_Float32_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Packed_Float32_Array, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

packed_float32_array_not :: proc {
    packed_float32_array_not_default,
}
packed_float32_array_in_dictionary :: proc "contextless" (self: Packed_Float32_Array, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Packed_Float32_Array, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_float32_array_in_array :: proc "contextless" (self: Packed_Float32_Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Packed_Float32_Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_float32_array_in :: proc {
    packed_float32_array_in_dictionary,
    packed_float32_array_in_array,
}
packed_float32_array_add_packed_float32_array :: proc "contextless" (self: Packed_Float32_Array, other: Packed_Float32_Array) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Packed_Float32_Array, .Packed_Float32_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_float32_array_add :: proc {
    packed_float32_array_add_packed_float32_array,
}

