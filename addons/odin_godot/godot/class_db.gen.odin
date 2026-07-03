package godot

import __bindgen_gde "godot:gdext"

Class_Db_Constants :: enum {
}
Class_Dbapi_Type :: enum int {
    Api_Core = 0,
    Api_Editor = 1,
    Api_Extension = 2,
    Api_Editor_Extension = 3,
    Api_None = 4,
}



class_db_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

class_db_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_class_db :: proc "contextless" () -> Class_Db {
    return __bindgen_gde.classdb_construct_object(class_db_name_ref())
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

class_db_get_class_list :: proc "contextless" (
    self: Class_Db,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_class_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_get_inheriters_from_class :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_inheriters_from_class", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1761182771)
    }
    self := self
    class_ := class_
    args := []__bindgen_gde.TypePtr {
        &class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_get_parent_class :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_parent_class", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965194235)
    }
    self := self
    class_ := class_
    args := []__bindgen_gde.TypePtr {
        &class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_exists :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_exists", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    class_ := class_
    args := []__bindgen_gde.TypePtr {
        &class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_is_parent_class :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    inherits_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_parent_class", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    class_ := class_
    inherits_ := inherits_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &inherits_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_can_instantiate :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("can_instantiate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    class_ := class_
    args := []__bindgen_gde.TypePtr {
        &class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_instantiate :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("instantiate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2760726917)
    }
    self := self
    class_ := class_
    args := []__bindgen_gde.TypePtr {
        &class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_api_type :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
) -> (ret: Class_Dbapi_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_api_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2475317043)
    }
    self := self
    class_ := class_
    args := []__bindgen_gde.TypePtr {
        &class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_has_signal :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    signal_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_has_signal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    class_ := class_
    signal_ := signal_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &signal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_signal :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    signal_: String_Name,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_signal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3061114238)
    }
    self := self
    class_ := class_
    signal_ := signal_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &signal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_signal_list :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_signal_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3504980660)
    }
    self := self
    class_ := class_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_property_list :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_property_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3504980660)
    }
    self := self
    class_ := class_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_property_getter :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    property_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_property_getter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3770832642)
    }
    self := self
    class_ := class_
    property_ := property_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &property_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_property_setter :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    property_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_property_setter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3770832642)
    }
    self := self
    class_ := class_
    property_ := property_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &property_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_property :: proc "contextless" (
    self: Class_Db,
    object_: Object,
    property_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2498641674)
    }
    self := self
    object_ := object_
    property_ := property_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &property_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_set_property :: proc "contextless" (
    self: Class_Db,
    object_: Object,
    property_: String_Name,
    value_: Variant,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_set_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1690314931)
    }
    self := self
    object_ := object_
    property_ := property_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &property_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_property_default_value :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    property_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_property_default_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2718203076)
    }
    self := self
    class_ := class_
    property_ := property_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &property_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_has_method :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    method_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_has_method", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3860701026)
    }
    self := self
    class_ := class_
    method_ := method_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &method_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_method_argument_count :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    method_: String_Name,
    no_inheritance_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_method_argument_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3885694822)
    }
    self := self
    class_ := class_
    method_ := method_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &method_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_method_list :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_method_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3504980660)
    }
    self := self
    class_ := class_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_call_static :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    method_: String_Name,
    extra: ..Variant,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_call_static", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3344196419)
    }
    self := self
    class_ := class_
    __fv_class := variant_from(&class_)
    method_ := method_
    __fv_method := variant_from(&method_)
    __argv: [64]__bindgen_gde.VariantPtr
    __n := 0
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_class
    __n += 1
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_method
    __n += 1
    for __i in 0 ..< len(extra) {
        if __n >= 64 do break
        __argv[__n] = cast(__bindgen_gde.VariantPtr)&extra[__i]
        __n += 1
    }
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(__bindgen_gde.VariantPtr)&ret, nil)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_class)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_method)
    return
}

class_db_class_get_integer_constant_list :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_integer_constant_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3031669221)
    }
    self := self
    class_ := class_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_has_integer_constant :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_has_integer_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    class_ := class_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_integer_constant :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    name_: String_Name,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_integer_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2419549490)
    }
    self := self
    class_ := class_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_has_enum :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    name_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_has_enum", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3860701026)
    }
    self := self
    class_ := class_
    name_ := name_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &name_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_enum_list :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_enum_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3031669221)
    }
    self := self
    class_ := class_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_enum_constants :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    enum_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_enum_constants", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 661528303)
    }
    self := self
    class_ := class_
    enum_ := enum_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &enum_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_class_get_integer_constant_enum :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    name_: String_Name,
    no_inheritance_: Bool,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("class_get_integer_constant_enum", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2457504236)
    }
    self := self
    class_ := class_
    name_ := name_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &name_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_is_class_enum_bitfield :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
    enum_: String_Name,
    no_inheritance_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_class_enum_bitfield", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3860701026)
    }
    self := self
    class_ := class_
    enum_ := enum_
    no_inheritance_ := no_inheritance_
    args := []__bindgen_gde.TypePtr {
        &class_,
        &enum_,
        &no_inheritance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

class_db_is_class_enabled :: proc "contextless" (
    self: Class_Db,
    class_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_class_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    class_ := class_
    args := []__bindgen_gde.TypePtr {
        &class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
class_db_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ClassDB", true)
}

@(private = "file")
__class_name: String_Name