package godot

import __bindgen_gde "godot:gdext"


new_packed_color_array :: proc {
    new_packed_color_array_default,
    new_packed_color_array_packed_color_array,
    new_packed_color_array_array,
}

new_packed_color_array_default :: proc "contextless" (
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Color_Array, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_packed_color_array_packed_color_array :: proc "contextless" (
    from_: Packed_Color_Array,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Color_Array, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_packed_color_array_array :: proc "contextless" (
    from_: Array,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Color_Array, 2)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_packed_color_array :: proc "contextless" (self: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Packed_Color_Array)
    }

    self := self
    __ptr(&self)
}

// members


packed_color_array_get :: proc "contextless" (
    self: ^Packed_Color_Array,
    index_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 2972831132)
    }
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_set :: proc "contextless" (
    self: ^Packed_Color_Array,
    index_: Int,
    value_: Color,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 1444096570)
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
packed_color_array_size :: proc "contextless" (
    self: ^Packed_Color_Array,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_is_empty :: proc "contextless" (
    self: ^Packed_Color_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_push_back :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_back", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 1007858200)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_append :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 1007858200)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_append_array :: proc "contextless" (
    self: ^Packed_Color_Array,
    array_: Packed_Color_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 798822497)
    }
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_color_array_remove_at :: proc "contextless" (
    self: ^Packed_Color_Array,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 2823966027)
    }
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_color_array_insert :: proc "contextless" (
    self: ^Packed_Color_Array,
    at_index_: Int,
    value_: Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 785289703)
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
packed_color_array_fill :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3730314301)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_color_array_resize :: proc "contextless" (
    self: ^Packed_Color_Array,
    new_size_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resize", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 848867239)
    }
    new_size_ := new_size_
    args := []__bindgen_gde.TypePtr {
        &new_size_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_clear :: proc "contextless" (
    self: ^Packed_Color_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_color_array_has :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3167426256)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_reverse :: proc "contextless" (
    self: ^Packed_Color_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_color_array_slice :: proc "contextless" (
    self: ^Packed_Color_Array,
    begin_: Int,
    end_: Int,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slice", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 2451797139)
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
packed_color_array_to_byte_array :: proc "contextless" (
    self: ^Packed_Color_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_byte_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_sort :: proc "contextless" (
    self: ^Packed_Color_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sort", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_color_array_bsearch :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
    before_: Bool,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bsearch", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 2639732838)
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
packed_color_array_duplicate :: proc "contextless" (
    self: ^Packed_Color_Array,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3072026941)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_find :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3156095363)
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
packed_color_array_rfind :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rfind", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 3156095363)
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
packed_color_array_count :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 1682108616)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_color_array_erase :: proc "contextless" (
    self: ^Packed_Color_Array,
    value_: Color,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Color_Array, &_gde_name, 1007858200)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

packed_color_array_equal_variant :: proc "contextless" (self: Packed_Color_Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Packed_Color_Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_color_array_equal_packed_color_array :: proc "contextless" (self: Packed_Color_Array, other: Packed_Color_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Packed_Color_Array, .Packed_Color_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_color_array_equal :: proc {
    packed_color_array_equal_variant,
    packed_color_array_equal_packed_color_array,
}
packed_color_array_not_equal_variant :: proc "contextless" (self: Packed_Color_Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Packed_Color_Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_color_array_not_equal_packed_color_array :: proc "contextless" (self: Packed_Color_Array, other: Packed_Color_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Packed_Color_Array, .Packed_Color_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_color_array_not_equal :: proc {
    packed_color_array_not_equal_variant,
    packed_color_array_not_equal_packed_color_array,
}
packed_color_array_not_default :: proc "contextless" (self: Packed_Color_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Packed_Color_Array, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

packed_color_array_not :: proc {
    packed_color_array_not_default,
}
packed_color_array_in_dictionary :: proc "contextless" (self: Packed_Color_Array, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Packed_Color_Array, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_color_array_in_array :: proc "contextless" (self: Packed_Color_Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Packed_Color_Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_color_array_in :: proc {
    packed_color_array_in_dictionary,
    packed_color_array_in_array,
}
packed_color_array_add_packed_color_array :: proc "contextless" (self: Packed_Color_Array, other: Packed_Color_Array) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Packed_Color_Array, .Packed_Color_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_color_array_add :: proc {
    packed_color_array_add_packed_color_array,
}

