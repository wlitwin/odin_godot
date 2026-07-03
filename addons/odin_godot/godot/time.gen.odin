package godot

import __bindgen_gde "godot:gdext"

Time_Constants :: enum {
}
Time_Month :: enum int {
    Month_January = 1,
    Month_February = 2,
    Month_March = 3,
    Month_April = 4,
    Month_May = 5,
    Month_June = 6,
    Month_July = 7,
    Month_August = 8,
    Month_September = 9,
    Month_October = 10,
    Month_November = 11,
    Month_December = 12,
}
Time_Weekday :: enum int {
    Weekday_Sunday = 0,
    Weekday_Monday = 1,
    Weekday_Tuesday = 2,
    Weekday_Wednesday = 3,
    Weekday_Thursday = 4,
    Weekday_Friday = 5,
    Weekday_Saturday = 6,
}



time_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

time_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_time :: proc "contextless" () -> Time {
    return __bindgen_gde.classdb_construct_object(time_name_ref())
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

time_get_datetime_dict_from_unix_time :: proc "contextless" (
    self: Time,
    unix_time_val_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_datetime_dict_from_unix_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3485342025)
    }
    self := self
    unix_time_val_ := unix_time_val_
    args := []__bindgen_gde.TypePtr {
        &unix_time_val_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_date_dict_from_unix_time :: proc "contextless" (
    self: Time,
    unix_time_val_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_date_dict_from_unix_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3485342025)
    }
    self := self
    unix_time_val_ := unix_time_val_
    args := []__bindgen_gde.TypePtr {
        &unix_time_val_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_time_dict_from_unix_time :: proc "contextless" (
    self: Time,
    unix_time_val_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_time_dict_from_unix_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3485342025)
    }
    self := self
    unix_time_val_ := unix_time_val_
    args := []__bindgen_gde.TypePtr {
        &unix_time_val_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_datetime_string_from_unix_time :: proc "contextless" (
    self: Time,
    unix_time_val_: Int,
    use_space_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_datetime_string_from_unix_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311239925)
    }
    self := self
    unix_time_val_ := unix_time_val_
    use_space_ := use_space_
    args := []__bindgen_gde.TypePtr {
        &unix_time_val_,
        &use_space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_date_string_from_unix_time :: proc "contextless" (
    self: Time,
    unix_time_val_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_date_string_from_unix_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    unix_time_val_ := unix_time_val_
    args := []__bindgen_gde.TypePtr {
        &unix_time_val_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_time_string_from_unix_time :: proc "contextless" (
    self: Time,
    unix_time_val_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_time_string_from_unix_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    unix_time_val_ := unix_time_val_
    args := []__bindgen_gde.TypePtr {
        &unix_time_val_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_datetime_dict_from_datetime_string :: proc "contextless" (
    self: Time,
    datetime_: String,
    weekday_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_datetime_dict_from_datetime_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3253569256)
    }
    self := self
    datetime_ := datetime_
    weekday_ := weekday_
    args := []__bindgen_gde.TypePtr {
        &datetime_,
        &weekday_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_datetime_string_from_datetime_dict :: proc "contextless" (
    self: Time,
    datetime_: Dictionary,
    use_space_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_datetime_string_from_datetime_dict", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1898123706)
    }
    self := self
    datetime_ := datetime_
    use_space_ := use_space_
    args := []__bindgen_gde.TypePtr {
        &datetime_,
        &use_space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_unix_time_from_datetime_dict :: proc "contextless" (
    self: Time,
    datetime_: Dictionary,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_unix_time_from_datetime_dict", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3021115443)
    }
    self := self
    datetime_ := datetime_
    args := []__bindgen_gde.TypePtr {
        &datetime_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_unix_time_from_datetime_string :: proc "contextless" (
    self: Time,
    datetime_: String,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_unix_time_from_datetime_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1321353865)
    }
    self := self
    datetime_ := datetime_
    args := []__bindgen_gde.TypePtr {
        &datetime_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_offset_string_from_offset_minutes :: proc "contextless" (
    self: Time,
    offset_minutes_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_offset_string_from_offset_minutes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    offset_minutes_ := offset_minutes_
    args := []__bindgen_gde.TypePtr {
        &offset_minutes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_datetime_dict_from_system :: proc "contextless" (
    self: Time,
    utc_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_datetime_dict_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 205769976)
    }
    self := self
    utc_ := utc_
    args := []__bindgen_gde.TypePtr {
        &utc_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_date_dict_from_system :: proc "contextless" (
    self: Time,
    utc_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_date_dict_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 205769976)
    }
    self := self
    utc_ := utc_
    args := []__bindgen_gde.TypePtr {
        &utc_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_time_dict_from_system :: proc "contextless" (
    self: Time,
    utc_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_time_dict_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 205769976)
    }
    self := self
    utc_ := utc_
    args := []__bindgen_gde.TypePtr {
        &utc_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_datetime_string_from_system :: proc "contextless" (
    self: Time,
    utc_: Bool,
    use_space_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_datetime_string_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1136425492)
    }
    self := self
    utc_ := utc_
    use_space_ := use_space_
    args := []__bindgen_gde.TypePtr {
        &utc_,
        &use_space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_date_string_from_system :: proc "contextless" (
    self: Time,
    utc_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_date_string_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1162154673)
    }
    self := self
    utc_ := utc_
    args := []__bindgen_gde.TypePtr {
        &utc_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_time_string_from_system :: proc "contextless" (
    self: Time,
    utc_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_time_string_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1162154673)
    }
    self := self
    utc_ := utc_
    args := []__bindgen_gde.TypePtr {
        &utc_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_time_zone_from_system :: proc "contextless" (
    self: Time,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_time_zone_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_unix_time_from_system :: proc "contextless" (
    self: Time,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_unix_time_from_system", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_ticks_msec :: proc "contextless" (
    self: Time,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ticks_msec", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

time_get_ticks_usec :: proc "contextless" (
    self: Time,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ticks_usec", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
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
time_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Time", true)
}

@(private = "file")
__class_name: String_Name