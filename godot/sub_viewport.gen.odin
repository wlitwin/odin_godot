package godot

import __bindgen_gde "godot:gdext"

Sub_Viewport_Constants :: enum {
}
Sub_Viewport_Clear_Mode :: enum int {
    Clear_Mode_Always = 0,
    Clear_Mode_Never = 1,
    Clear_Mode_Once = 2,
}
Sub_Viewport_Update_Mode :: enum int {
    Update_Disabled = 0,
    Update_Once = 1,
    Update_When_Visible = 2,
    Update_When_Parent_Visible = 3,
    Update_Always = 4,
}



sub_viewport_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

sub_viewport_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_sub_viewport :: proc "contextless" () -> Sub_Viewport {
    return __bindgen_gde.classdb_construct_object(sub_viewport_name_ref())
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

sub_viewport_set_size :: proc "contextless" (
    self: Sub_Viewport,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sub_viewport_get_size :: proc "contextless" (
    self: Sub_Viewport,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sub_viewport_set_size_2d_override :: proc "contextless" (
    self: Sub_Viewport,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size_2d_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sub_viewport_get_size_2d_override :: proc "contextless" (
    self: Sub_Viewport,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size_2d_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sub_viewport_set_size_2d_override_stretch :: proc "contextless" (
    self: Sub_Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size_2d_override_stretch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sub_viewport_is_size_2d_override_stretch_enabled :: proc "contextless" (
    self: Sub_Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_size_2d_override_stretch_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sub_viewport_set_view_count :: proc "contextless" (
    self: Sub_Viewport,
    view_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_view_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    view_count_ := view_count_
    args := []__bindgen_gde.TypePtr {
        &view_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sub_viewport_get_view_count :: proc "contextless" (
    self: Sub_Viewport,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_view_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sub_viewport_set_update_mode :: proc "contextless" (
    self: Sub_Viewport,
    mode_: Sub_Viewport_Update_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1295690030)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sub_viewport_get_update_mode :: proc "contextless" (
    self: Sub_Viewport,
) -> (ret: Sub_Viewport_Update_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2980171553)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sub_viewport_set_clear_mode :: proc "contextless" (
    self: Sub_Viewport,
    mode_: Sub_Viewport_Clear_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clear_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2834454712)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sub_viewport_get_clear_mode :: proc "contextless" (
    self: Sub_Viewport,
) -> (ret: Sub_Viewport_Clear_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clear_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 331324495)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
sub_viewport_get_size_2d_override_stretch :: proc "contextless" (self: Sub_Viewport) -> Bool {
    return sub_viewport_is_size_2d_override_stretch_enabled(self)
}
sub_viewport_get_render_target_clear_mode :: proc "contextless" (self: Sub_Viewport) -> Sub_Viewport_Clear_Mode {
    return sub_viewport_get_clear_mode(self)
}
sub_viewport_set_render_target_clear_mode :: proc "contextless" (self: Sub_Viewport, value: Sub_Viewport_Clear_Mode) {
    sub_viewport_set_clear_mode(self, value)
}
sub_viewport_get_render_target_update_mode :: proc "contextless" (self: Sub_Viewport) -> Sub_Viewport_Update_Mode {
    return sub_viewport_get_update_mode(self)
}
sub_viewport_set_render_target_update_mode :: proc "contextless" (self: Sub_Viewport, value: Sub_Viewport_Update_Mode) {
    sub_viewport_set_update_mode(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
sub_viewport_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SubViewport", true)
}

@(private = "file")
__class_name: String_Name