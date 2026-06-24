package godot

import __bindgen_gde "godot:gdext"


new_array :: proc {
    new_array_default,
    new_array_array,
    new_array_array_int_string_name_variant,
    new_array_packed_byte_array,
    new_array_packed_int32_array,
    new_array_packed_int64_array,
    new_array_packed_float32_array,
    new_array_packed_float64_array,
    new_array_packed_string_array,
    new_array_packed_vector2_array,
    new_array_packed_vector3_array,
    new_array_packed_color_array,
    new_array_packed_vector4_array,
}

new_array_default :: proc "contextless" (
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_array :: proc "contextless" (
    from_: Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_array_int_string_name_variant :: proc "contextless" (
    base_: Array,
    type_: Int,
    class_name_: String_Name,
    script_: Variant,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 2)
    }
    base_ := base_
    type_ := type_
    class_name_ := class_name_
    script_ := script_
    args := []__bindgen_gde.TypePtr {
        &base_,
        &type_,
        &class_name_,
        &script_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_byte_array :: proc "contextless" (
    from_: Packed_Byte_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 3)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_int32_array :: proc "contextless" (
    from_: Packed_Int32_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 4)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_int64_array :: proc "contextless" (
    from_: Packed_Int64_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 5)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_float32_array :: proc "contextless" (
    from_: Packed_Float32_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 6)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_float64_array :: proc "contextless" (
    from_: Packed_Float64_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 7)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_string_array :: proc "contextless" (
    from_: Packed_String_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 8)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_vector2_array :: proc "contextless" (
    from_: Packed_Vector2_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 9)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_vector3_array :: proc "contextless" (
    from_: Packed_Vector3_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 10)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_color_array :: proc "contextless" (
    from_: Packed_Color_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 11)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_array_packed_vector4_array :: proc "contextless" (
    from_: Packed_Vector4_Array,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Array, 12)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_array :: proc "contextless" (self: Array) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Array)
    }

    self := self
    __ptr(&self)
}

// members


array_size :: proc "contextless" (
    self: ^Array,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_is_empty :: proc "contextless" (
    self: ^Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_clear :: proc "contextless" (
    self: ^Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_hash :: proc "contextless" (
    self: ^Array,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hash", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_assign :: proc "contextless" (
    self: ^Array,
    array_: Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("assign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2307260970)
    }
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_get :: proc "contextless" (
    self: ^Array,
    index_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 708700221)
    }
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_set :: proc "contextless" (
    self: ^Array,
    index_: Int,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3798478031)
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
array_push_back :: proc "contextless" (
    self: ^Array,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_back", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3316032543)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_push_front :: proc "contextless" (
    self: ^Array,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_front", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3316032543)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_append :: proc "contextless" (
    self: ^Array,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3316032543)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_append_array :: proc "contextless" (
    self: ^Array,
    array_: Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2307260970)
    }
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_resize :: proc "contextless" (
    self: ^Array,
    size_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resize", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 848867239)
    }
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_insert :: proc "contextless" (
    self: ^Array,
    position_: Int,
    value_: Variant,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3176316662)
    }
    position_ := position_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_remove_at :: proc "contextless" (
    self: ^Array,
    position_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2823966027)
    }
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_fill :: proc "contextless" (
    self: ^Array,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3316032543)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_erase :: proc "contextless" (
    self: ^Array,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3316032543)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_front :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("front", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_back :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("back", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_pick_random :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pick_random", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_find :: proc "contextless" (
    self: ^Array,
    what_: Variant,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2336346817)
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
array_find_custom :: proc "contextless" (
    self: ^Array,
    method_: Callable,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_custom", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2145562546)
    }
    method_ := method_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_rfind :: proc "contextless" (
    self: ^Array,
    what_: Variant,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rfind", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2336346817)
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
array_rfind_custom :: proc "contextless" (
    self: ^Array,
    method_: Callable,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rfind_custom", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2145562546)
    }
    method_ := method_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &from_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_count :: proc "contextless" (
    self: ^Array,
    value_: Variant,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1481661226)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_has :: proc "contextless" (
    self: ^Array,
    value_: Variant,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3680194679)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_pop_back :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pop_back", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1321915136)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_pop_front :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pop_front", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1321915136)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_pop_at :: proc "contextless" (
    self: ^Array,
    position_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pop_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3518259424)
    }
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_sort :: proc "contextless" (
    self: ^Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sort", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_sort_custom :: proc "contextless" (
    self: ^Array,
    func_: Callable,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sort_custom", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3470848906)
    }
    func_ := func_
    args := []__bindgen_gde.TypePtr {
        &func_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_shuffle :: proc "contextless" (
    self: ^Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shuffle", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_bsearch :: proc "contextless" (
    self: ^Array,
    value_: Variant,
    before_: Bool,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bsearch", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3372222236)
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
array_bsearch_custom :: proc "contextless" (
    self: ^Array,
    value_: Variant,
    func_: Callable,
    before_: Bool,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bsearch_custom", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 161317131)
    }
    value_ := value_
    func_ := func_
    before_ := before_
    args := []__bindgen_gde.TypePtr {
        &value_,
        &func_,
        &before_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_reverse :: proc "contextless" (
    self: ^Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_duplicate :: proc "contextless" (
    self: ^Array,
    deep_: Bool,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 636440122)
    }
    deep_ := deep_
    args := []__bindgen_gde.TypePtr {
        &deep_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_duplicate_deep :: proc "contextless" (
    self: ^Array,
    deep_subresources_mode_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate_deep", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1949240801)
    }
    deep_subresources_mode_ := deep_subresources_mode_
    args := []__bindgen_gde.TypePtr {
        &deep_subresources_mode_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_slice :: proc "contextless" (
    self: ^Array,
    begin_: Int,
    end_: Int,
    step_: Int,
    deep_: Bool,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slice", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1393718243)
    }
    begin_ := begin_
    end_ := end_
    step_ := step_
    deep_ := deep_
    args := []__bindgen_gde.TypePtr {
        &begin_,
        &end_,
        &step_,
        &deep_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_filter :: proc "contextless" (
    self: ^Array,
    method_: Callable,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("filter", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 4075186556)
    }
    method_ := method_
    args := []__bindgen_gde.TypePtr {
        &method_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_map :: proc "contextless" (
    self: ^Array,
    method_: Callable,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("map", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 4075186556)
    }
    method_ := method_
    args := []__bindgen_gde.TypePtr {
        &method_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_reduce :: proc "contextless" (
    self: ^Array,
    method_: Callable,
    accum_: Variant,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reduce", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 4272450342)
    }
    method_ := method_
    accum_ := accum_
    args := []__bindgen_gde.TypePtr {
        &method_,
        &accum_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_any :: proc "contextless" (
    self: ^Array,
    method_: Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("any", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 4129521963)
    }
    method_ := method_
    args := []__bindgen_gde.TypePtr {
        &method_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_all :: proc "contextless" (
    self: ^Array,
    method_: Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("all", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 4129521963)
    }
    method_ := method_
    args := []__bindgen_gde.TypePtr {
        &method_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_max :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_min :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_is_typed :: proc "contextless" (
    self: ^Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_typed", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_is_same_typed :: proc "contextless" (
    self: ^Array,
    array_: Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_same_typed", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 2988181878)
    }
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_get_typed_builtin :: proc "contextless" (
    self: ^Array,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_builtin", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_get_typed_class_name :: proc "contextless" (
    self: ^Array,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_class_name", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1825232092)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_get_typed_script :: proc "contextless" (
    self: ^Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_typed_script", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 1460142086)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
array_make_read_only :: proc "contextless" (
    self: ^Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_read_only", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
array_is_read_only :: proc "contextless" (
    self: ^Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_read_only", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Array, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

array_equal_variant :: proc "contextless" (self: Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
array_equal_array :: proc "contextless" (self: Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_equal :: proc {
    array_equal_variant,
    array_equal_array,
}
array_not_equal_variant :: proc "contextless" (self: Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
array_not_equal_array :: proc "contextless" (self: Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_not_equal :: proc {
    array_not_equal_variant,
    array_not_equal_array,
}
array_not_default :: proc "contextless" (self: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Array, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

array_not :: proc {
    array_not_default,
}
array_in_dictionary :: proc "contextless" (self: Array, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Array, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
array_in_array :: proc "contextless" (self: Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_in :: proc {
    array_in_dictionary,
    array_in_array,
}
array_less_array :: proc "contextless" (self: Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_less :: proc {
    array_less_array,
}
array_less_equal_array :: proc "contextless" (self: Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_less_equal :: proc {
    array_less_equal_array,
}
array_greater_array :: proc "contextless" (self: Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_greater :: proc {
    array_greater_array,
}
array_greater_equal_array :: proc "contextless" (self: Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_greater_equal :: proc {
    array_greater_equal_array,
}
array_add_array :: proc "contextless" (self: Array, other: Array) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

array_add :: proc {
    array_add_array,
}

