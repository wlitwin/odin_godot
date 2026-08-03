package godot

import __bindgen_gde "godot:gdext"

Theme_Db_Constants :: enum {
}



theme_db_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

theme_db_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_theme_db :: proc "contextless" () -> Theme_Db {
    return cast(Theme_Db)__bindgen_gde.classdb_construct_object(theme_db_name_ref())
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

theme_db_get_default_theme :: proc "contextless" (
    self: Theme_Db,
) -> (ret: Theme) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_theme", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 754276358)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_db_get_project_theme :: proc "contextless" (
    self: Theme_Db,
) -> (ret: Theme) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_project_theme", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 754276358)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_db_set_fallback_base_scale :: proc "contextless" (
    self: Theme_Db,
    base_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallback_base_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    base_scale_ := base_scale_
    args := []__bindgen_gde.TypePtr {
        &base_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_db_get_fallback_base_scale :: proc "contextless" (
    self: Theme_Db,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallback_base_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_db_set_fallback_font :: proc "contextless" (
    self: Theme_Db,
    font_: Font,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallback_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1262170328)
    }
    self := self
    font_ := font_
    args := []__bindgen_gde.TypePtr {
        &font_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_db_get_fallback_font :: proc "contextless" (
    self: Theme_Db,
) -> (ret: Font) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallback_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3656929885)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_db_set_fallback_font_size :: proc "contextless" (
    self: Theme_Db,
    font_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallback_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_db_get_fallback_font_size :: proc "contextless" (
    self: Theme_Db,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallback_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_db_set_fallback_icon :: proc "contextless" (
    self: Theme_Db,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallback_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_db_get_fallback_icon :: proc "contextless" (
    self: Theme_Db,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallback_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 255860311)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

theme_db_set_fallback_stylebox :: proc "contextless" (
    self: Theme_Db,
    stylebox_: Style_Box,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallback_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2797200388)
    }
    self := self
    stylebox_ := stylebox_
    args := []__bindgen_gde.TypePtr {
        &stylebox_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

theme_db_get_fallback_stylebox :: proc "contextless" (
    self: Theme_Db,
) -> (ret: Style_Box) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallback_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 496040854)
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
theme_db_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ThemeDB", true)
}

@(private = "file")
__class_name: String_Name