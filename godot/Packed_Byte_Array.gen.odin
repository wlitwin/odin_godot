package godot

import __bindgen_gde "godot:gdext"


new_packed_byte_array :: proc {
    new_packed_byte_array_default,
    new_packed_byte_array_packed_byte_array,
    new_packed_byte_array_array,
}

new_packed_byte_array_default :: proc "contextless" (
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Byte_Array, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_packed_byte_array_packed_byte_array :: proc "contextless" (
    from_: Packed_Byte_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Byte_Array, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_packed_byte_array_array :: proc "contextless" (
    from_: Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Packed_Byte_Array, 2)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_packed_byte_array :: proc "contextless" (self: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Packed_Byte_Array)
    }

    self := self
    __ptr(&self)
}

// members


packed_byte_array_get :: proc "contextless" (
    self: ^Packed_Byte_Array,
    index_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_set :: proc "contextless" (
    self: ^Packed_Byte_Array,
    index_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
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
packed_byte_array_size :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_is_empty :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_push_back :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_back", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 694024632)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_append :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 694024632)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_append_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
    array_: Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 791097111)
    }
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_remove_at :: proc "contextless" (
    self: ^Packed_Byte_Array,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2823966027)
    }
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_insert :: proc "contextless" (
    self: ^Packed_Byte_Array,
    at_index_: Int,
    value_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1487112728)
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
packed_byte_array_fill :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2823966027)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_resize :: proc "contextless" (
    self: ^Packed_Byte_Array,
    new_size_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resize", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 848867239)
    }
    new_size_ := new_size_
    args := []__bindgen_gde.TypePtr {
        &new_size_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_clear :: proc "contextless" (
    self: ^Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_has :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 931488181)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_reverse :: proc "contextless" (
    self: ^Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_slice :: proc "contextless" (
    self: ^Packed_Byte_Array,
    begin_: Int,
    end_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slice", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2278869132)
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
packed_byte_array_sort :: proc "contextless" (
    self: ^Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sort", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3218959716)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_bsearch :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
    before_: Bool,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bsearch", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 954237325)
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
packed_byte_array_duplicate :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 247621236)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_find :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2984303840)
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
packed_byte_array_rfind :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
    from_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rfind", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2984303840)
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
packed_byte_array_count :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_erase :: proc "contextless" (
    self: ^Packed_Byte_Array,
    value_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 694024632)
    }
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_get_string_from_ascii :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_from_ascii", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_get_string_from_utf8 :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_from_utf8", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_get_string_from_utf16 :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_from_utf16", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_get_string_from_utf32 :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_from_utf32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_get_string_from_wchar :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_from_wchar", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_get_string_from_multibyte_char :: proc "contextless" (
    self: ^Packed_Byte_Array,
    encoding_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_from_multibyte_char", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3134094431)
    }
    encoding_ := encoding_
    args := []__bindgen_gde.TypePtr {
        &encoding_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_hex_encode :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hex_encode", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3942272618)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_compress :: proc "contextless" (
    self: ^Packed_Byte_Array,
    compression_mode_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compress", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1845905913)
    }
    compression_mode_ := compression_mode_
    args := []__bindgen_gde.TypePtr {
        &compression_mode_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decompress :: proc "contextless" (
    self: ^Packed_Byte_Array,
    buffer_size_: Int,
    compression_mode_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decompress", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2278869132)
    }
    buffer_size_ := buffer_size_
    compression_mode_ := compression_mode_
    args := []__bindgen_gde.TypePtr {
        &buffer_size_,
        &compression_mode_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decompress_dynamic :: proc "contextless" (
    self: ^Packed_Byte_Array,
    max_output_size_: Int,
    compression_mode_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decompress_dynamic", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2278869132)
    }
    max_output_size_ := max_output_size_
    compression_mode_ := compression_mode_
    args := []__bindgen_gde.TypePtr {
        &max_output_size_,
        &compression_mode_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_u8 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_u8", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_s8 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_s8", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_u16 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_u16", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_s16 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_s16", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_u32 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_u32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_s32 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_s32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_u64 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_u64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_s64 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_s64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4103005248)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_half :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_half", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1401583798)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_float :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_float", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1401583798)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_double :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_double", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1401583798)
    }
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_has_encoded_var :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    allow_objects_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_encoded_var", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2914632957)
    }
    byte_offset_ := byte_offset_
    allow_objects_ := allow_objects_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &allow_objects_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_var :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    allow_objects_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_var", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1740420038)
    }
    byte_offset_ := byte_offset_
    allow_objects_ := allow_objects_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &allow_objects_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_decode_var_size :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    allow_objects_: Bool,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decode_var_size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 954237325)
    }
    byte_offset_ := byte_offset_
    allow_objects_ := allow_objects_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &allow_objects_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_int32_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_int32_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3158844420)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_int64_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_int64_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1961294120)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_float32_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_float32_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3575107827)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_float64_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Float64_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_float64_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1627308337)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_vector2_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_vector2_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1660374357)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_vector3_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_vector3_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 4171207452)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_vector4_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Vector4_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_vector4_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 146203628)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_to_color_array :: proc "contextless" (
    self: ^Packed_Byte_Array,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_color_array", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3072026941)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
packed_byte_array_bswap16 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    offset_: Int,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bswap16", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    offset_ := offset_
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &offset_,
        &count_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_bswap32 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    offset_: Int,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bswap32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    offset_ := offset_
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &offset_,
        &count_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_bswap64 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    offset_: Int,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bswap64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    offset_ := offset_
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &offset_,
        &count_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_u8 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_u8", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_s8 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_s8", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_u16 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_u16", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_s16 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_s16", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_u32 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_u32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_s32 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_s32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_u64 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_u64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_s64 :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_s64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 3638975848)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_half :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_half", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1113000516)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_float :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_float", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1113000516)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_double :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_double", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 1113000516)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
packed_byte_array_encode_var :: proc "contextless" (
    self: ^Packed_Byte_Array,
    byte_offset_: Int,
    value_: Variant,
    allow_objects_: Bool,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_var", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Packed_Byte_Array, &_gde_name, 2604460497)
    }
    byte_offset_ := byte_offset_
    value_ := value_
    allow_objects_ := allow_objects_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
        &value_,
        &allow_objects_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

packed_byte_array_equal_variant :: proc "contextless" (self: Packed_Byte_Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Packed_Byte_Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_byte_array_equal_packed_byte_array :: proc "contextless" (self: Packed_Byte_Array, other: Packed_Byte_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Packed_Byte_Array, .Packed_Byte_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_byte_array_equal :: proc {
    packed_byte_array_equal_variant,
    packed_byte_array_equal_packed_byte_array,
}
packed_byte_array_not_equal_variant :: proc "contextless" (self: Packed_Byte_Array, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Packed_Byte_Array, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_byte_array_not_equal_packed_byte_array :: proc "contextless" (self: Packed_Byte_Array, other: Packed_Byte_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Packed_Byte_Array, .Packed_Byte_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_byte_array_not_equal :: proc {
    packed_byte_array_not_equal_variant,
    packed_byte_array_not_equal_packed_byte_array,
}
packed_byte_array_not_default :: proc "contextless" (self: Packed_Byte_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Packed_Byte_Array, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

packed_byte_array_not :: proc {
    packed_byte_array_not_default,
}
packed_byte_array_in_dictionary :: proc "contextless" (self: Packed_Byte_Array, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Packed_Byte_Array, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
packed_byte_array_in_array :: proc "contextless" (self: Packed_Byte_Array, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Packed_Byte_Array, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_byte_array_in :: proc {
    packed_byte_array_in_dictionary,
    packed_byte_array_in_array,
}
packed_byte_array_add_packed_byte_array :: proc "contextless" (self: Packed_Byte_Array, other: Packed_Byte_Array) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Packed_Byte_Array, .Packed_Byte_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

packed_byte_array_add :: proc {
    packed_byte_array_add_packed_byte_array,
}

