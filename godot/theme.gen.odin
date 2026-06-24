package godot

import __bindgen_gde "godot:gdext"

Theme_Constants :: enum {
}
Theme_Data_Type :: enum int {
    Data_Type_Color = 0,
    Data_Type_Constant = 1,
    Data_Type_Font = 2,
    Data_Type_Font_Size = 3,
    Data_Type_Icon = 4,
    Data_Type_Stylebox = 5,
    Data_Type_Max = 6,
}



theme_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

theme_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_theme :: proc "contextless" () -> Theme {
    return cast(Theme)__bindgen_gde.classdb_construct_object(theme_name_ref())
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

theme_set_icon :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2188371082)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_icon :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 934555193)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_icon :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_rename_icon :: proc "contextless" (
    self: Theme,
    old_name_: String_Name,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 642128662)
    }
    self := self
    old_name_ := old_name_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear_icon :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_icon_list :: proc "contextless" (
    self: Theme,
    theme_type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_icon_type_list :: proc "contextless" (
    self: Theme,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_stylebox :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
    texture_: Style_Box,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2075907568)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_stylebox :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Style_Box) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3405608165)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_stylebox :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_rename_stylebox :: proc "contextless" (
    self: Theme,
    old_name_: String_Name,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 642128662)
    }
    self := self
    old_name_ := old_name_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear_stylebox :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_stylebox_list :: proc "contextless" (
    self: Theme,
    theme_type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stylebox_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_stylebox_type_list :: proc "contextless" (
    self: Theme,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stylebox_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_font :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
    font_: Font,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 177292320)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    font_ := font_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
        &font_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_font :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Font) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3445063586)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_font :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_rename_font :: proc "contextless" (
    self: Theme,
    old_name_: String_Name,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 642128662)
    }
    self := self
    old_name_ := old_name_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear_font :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_font_list :: proc "contextless" (
    self: Theme,
    theme_type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_font_type_list :: proc "contextless" (
    self: Theme,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_font_size :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
    font_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 281601298)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_font_size :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2419549490)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_font_size :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_rename_font_size :: proc "contextless" (
    self: Theme,
    old_name_: String_Name,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 642128662)
    }
    self := self
    old_name_ := old_name_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear_font_size :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_font_size_list :: proc "contextless" (
    self: Theme,
    theme_type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_size_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_font_size_type_list :: proc "contextless" (
    self: Theme,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_size_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_color :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4111215154)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_color :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2015923404)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_color :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_rename_color :: proc "contextless" (
    self: Theme,
    old_name_: String_Name,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 642128662)
    }
    self := self
    old_name_ := old_name_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear_color :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_color_list :: proc "contextless" (
    self: Theme,
    theme_type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_color_type_list :: proc "contextless" (
    self: Theme,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_constant :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
    constant_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 281601298)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    constant_ := constant_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
        &constant_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_constant :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2419549490)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_constant :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_rename_constant :: proc "contextless" (
    self: Theme,
    old_name_: String_Name,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 642128662)
    }
    self := self
    old_name_ := old_name_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear_constant :: proc "contextless" (
    self: Theme,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_constant_list :: proc "contextless" (
    self: Theme,
    theme_type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_constant_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_constant_type_list :: proc "contextless" (
    self: Theme,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_constant_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_default_base_scale :: proc "contextless" (
    self: Theme,
    base_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_base_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    base_scale_ := base_scale_
    args := []__bindgen_gde.TypePtr {
        &base_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_default_base_scale :: proc "contextless" (
    self: Theme,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_base_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_default_base_scale :: proc "contextless" (
    self: Theme,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_default_base_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_default_font :: proc "contextless" (
    self: Theme,
    font_: Font,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1262170328)
    }
    self := self
    font_ := font_
    args := []__bindgen_gde.TypePtr {
        &font_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_default_font :: proc "contextless" (
    self: Theme,
) -> (ret: Font) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229501585)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_default_font :: proc "contextless" (
    self: Theme,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_default_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_default_font_size :: proc "contextless" (
    self: Theme,
    font_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_default_font_size :: proc "contextless" (
    self: Theme,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_default_font_size :: proc "contextless" (
    self: Theme,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_default_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_theme_item :: proc "contextless" (
    self: Theme,
    data_type_: Theme_Data_Type,
    name_: String_Name,
    theme_type_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_theme_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2492983623)
    }
    self := self
    data_type_ := data_type_
    name_ := name_
    theme_type_ := theme_type_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &data_type_,
        &name_,
        &theme_type_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_theme_item :: proc "contextless" (
    self: Theme,
    data_type_: Theme_Data_Type,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2191024021)
    }
    self := self
    data_type_ := data_type_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &data_type_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_has_theme_item :: proc "contextless" (
    self: Theme,
    data_type_: Theme_Data_Type,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1739311056)
    }
    self := self
    data_type_ := data_type_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &data_type_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_rename_theme_item :: proc "contextless" (
    self: Theme,
    data_type_: Theme_Data_Type,
    old_name_: String_Name,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_theme_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3900867553)
    }
    self := self
    data_type_ := data_type_
    old_name_ := old_name_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &data_type_,
        &old_name_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear_theme_item :: proc "contextless" (
    self: Theme,
    data_type_: Theme_Data_Type,
    name_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_theme_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2965505587)
    }
    self := self
    data_type_ := data_type_
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &data_type_,
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_theme_item_list :: proc "contextless" (
    self: Theme,
    data_type_: Theme_Data_Type,
    theme_type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_item_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3726716710)
    }
    self := self
    data_type_ := data_type_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &data_type_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_theme_item_type_list :: proc "contextless" (
    self: Theme,
    data_type_: Theme_Data_Type,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_item_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1316004935)
    }
    self := self
    data_type_ := data_type_
    args := []__bindgen_gde.TypePtr {
        &data_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_set_type_variation :: proc "contextless" (
    self: Theme,
    theme_type_: String_Name,
    base_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_type_variation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    theme_type_ := theme_type_
    base_type_ := base_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
        &base_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_is_type_variation :: proc "contextless" (
    self: Theme,
    theme_type_: String_Name,
    base_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_type_variation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    theme_type_ := theme_type_
    base_type_ := base_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
        &base_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_clear_type_variation :: proc "contextless" (
    self: Theme,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_type_variation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_type_variation_base :: proc "contextless" (
    self: Theme,
    theme_type_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_type_variation_base", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965194235)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_get_type_variation_list :: proc "contextless" (
    self: Theme,
    base_type_: String_Name,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_type_variation_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1761182771)
    }
    self := self
    base_type_ := base_type_
    args := []__bindgen_gde.TypePtr {
        &base_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_add_type :: proc "contextless" (
    self: Theme,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_remove_type :: proc "contextless" (
    self: Theme,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_rename_type :: proc "contextless" (
    self: Theme,
    old_theme_type_: String_Name,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    old_theme_type_ := old_theme_type_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &old_theme_type_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_get_type_list :: proc "contextless" (
    self: Theme,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_type_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_merge_with :: proc "contextless" (
    self: Theme,
    other_: Theme,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge_with", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2326690814)
    }
    self := self
    other_ := other_
    args := []__bindgen_gde.TypePtr {
        &other_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_clear :: proc "contextless" (
    self: Theme,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
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
theme_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Theme", true)
}

@(private = "file")
__class_name: String_Name