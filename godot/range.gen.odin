package godot

import __bindgen_gde "godot:gdext"

Range_Constants :: enum {
}



range_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

range_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_range :: proc "contextless" () -> Range {
    return cast(Range)__bindgen_gde.classdb_construct_object(range_name_ref())
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

range__value_changed :: proc "contextless" (
    self: Range,
    new_value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_value_changed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    new_value_ := new_value_
    args := []__bindgen_gde.TypePtr {
        &new_value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_get_value :: proc "contextless" (
    self: Range,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_get_min :: proc "contextless" (
    self: Range,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_get_max :: proc "contextless" (
    self: Range,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_get_step :: proc "contextless" (
    self: Range,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_get_page :: proc "contextless" (
    self: Range,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_page", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_get_as_ratio :: proc "contextless" (
    self: Range,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_as_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_set_value :: proc "contextless" (
    self: Range,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_set_value_no_signal :: proc "contextless" (
    self: Range,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_value_no_signal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_set_min :: proc "contextless" (
    self: Range,
    minimum_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    minimum_ := minimum_
    args := []__bindgen_gde.TypePtr {
        &minimum_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_set_max :: proc "contextless" (
    self: Range,
    maximum_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    maximum_ := maximum_
    args := []__bindgen_gde.TypePtr {
        &maximum_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_set_step :: proc "contextless" (
    self: Range,
    step_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_set_page :: proc "contextless" (
    self: Range,
    pagesize_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_page", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    pagesize_ := pagesize_
    args := []__bindgen_gde.TypePtr {
        &pagesize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_set_as_ratio :: proc "contextless" (
    self: Range,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_as_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_set_use_rounded_values :: proc "contextless" (
    self: Range,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_rounded_values", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_is_using_rounded_values :: proc "contextless" (
    self: Range,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_rounded_values", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_set_exp_ratio :: proc "contextless" (
    self: Range,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_exp_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_is_ratio_exp :: proc "contextless" (
    self: Range,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_ratio_exp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_set_allow_greater :: proc "contextless" (
    self: Range,
    allow_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_allow_greater", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    allow_ := allow_
    args := []__bindgen_gde.TypePtr {
        &allow_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_is_greater_allowed :: proc "contextless" (
    self: Range,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_greater_allowed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_set_allow_lesser :: proc "contextless" (
    self: Range,
    allow_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_allow_lesser", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    allow_ := allow_
    args := []__bindgen_gde.TypePtr {
        &allow_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_is_lesser_allowed :: proc "contextless" (
    self: Range,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_lesser_allowed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

range_share :: proc "contextless" (
    self: Range,
    with_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("share", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

range_unshare :: proc "contextless" (
    self: Range,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unshare", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
range_get_min_value :: proc "contextless" (self: Range) -> f64 {
    return range_get_min(self)
}
range_set_min_value :: proc "contextless" (self: Range, value: f64) {
    range_set_min(self, value)
}
range_get_max_value :: proc "contextless" (self: Range) -> f64 {
    return range_get_max(self)
}
range_set_max_value :: proc "contextless" (self: Range, value: f64) {
    range_set_max(self, value)
}
range_get_ratio :: proc "contextless" (self: Range) -> f64 {
    return range_get_as_ratio(self)
}
range_set_ratio :: proc "contextless" (self: Range, value: f64) {
    range_set_as_ratio(self, value)
}
range_get_exp_edit :: proc "contextless" (self: Range) -> Bool {
    return range_is_ratio_exp(self)
}
range_set_exp_edit :: proc "contextless" (self: Range, value: Bool) {
    range_set_exp_ratio(self, value)
}
range_get_rounded :: proc "contextless" (self: Range) -> Bool {
    return range_is_using_rounded_values(self)
}
range_set_rounded :: proc "contextless" (self: Range, value: Bool) {
    range_set_use_rounded_values(self, value)
}
range_get_allow_greater :: proc "contextless" (self: Range) -> Bool {
    return range_is_greater_allowed(self)
}
range_get_allow_lesser :: proc "contextless" (self: Range) -> Bool {
    return range_is_lesser_allowed(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
range_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Range", true)
}

@(private = "file")
__class_name: String_Name