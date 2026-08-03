package godot

import __bindgen_gde "godot:gdext"

Scroll_Container_Constants :: enum {
}
Scroll_Container_Scroll_Mode :: enum int {
    Scroll_Mode_Disabled = 0,
    Scroll_Mode_Auto = 1,
    Scroll_Mode_Show_Always = 2,
    Scroll_Mode_Show_Never = 3,
    Scroll_Mode_Reserve = 4,
    Scroll_Mode_Maximize_First = 5,
}
Scroll_Container_Scroll_Hint_Mode :: enum int {
    Scroll_Hint_Mode_Disabled = 0,
    Scroll_Hint_Mode_All = 1,
    Scroll_Hint_Mode_Top_And_Left = 2,
    Scroll_Hint_Mode_Bottom_And_Right = 3,
}



scroll_container_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

scroll_container_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_scroll_container :: proc "contextless" () -> Scroll_Container {
    return cast(Scroll_Container)__bindgen_gde.classdb_construct_object(scroll_container_name_ref())
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

scroll_container_set_h_scroll :: proc "contextless" (
    self: Scroll_Container,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_h_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_h_scroll :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_v_scroll :: proc "contextless" (
    self: Scroll_Container,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_v_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_v_scroll :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_horizontal_custom_step :: proc "contextless" (
    self: Scroll_Container,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_horizontal_custom_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_horizontal_custom_step :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_horizontal_custom_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_vertical_custom_step :: proc "contextless" (
    self: Scroll_Container,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertical_custom_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_vertical_custom_step :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertical_custom_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_horizontal_scroll_mode :: proc "contextless" (
    self: Scroll_Container,
    enable_: Scroll_Container_Scroll_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_horizontal_scroll_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2750506364)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_horizontal_scroll_mode :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: Scroll_Container_Scroll_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_horizontal_scroll_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3987985145)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_vertical_scroll_mode :: proc "contextless" (
    self: Scroll_Container,
    enable_: Scroll_Container_Scroll_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertical_scroll_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2750506364)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_vertical_scroll_mode :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: Scroll_Container_Scroll_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertical_scroll_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3987985145)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_scroll_horizontal_by_default :: proc "contextless" (
    self: Scroll_Container,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scroll_horizontal_by_default", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_is_scroll_horizontal_by_default :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_scroll_horizontal_by_default", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_deadzone :: proc "contextless" (
    self: Scroll_Container,
    deadzone_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_deadzone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    deadzone_ := deadzone_
    args := []__bindgen_gde.TypePtr {
        &deadzone_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_deadzone :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_deadzone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_scroll_hint_mode :: proc "contextless" (
    self: Scroll_Container,
    scroll_hint_mode_: Scroll_Container_Scroll_Hint_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scroll_hint_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 578158943)
    }
    self := self
    scroll_hint_mode_ := scroll_hint_mode_
    args := []__bindgen_gde.TypePtr {
        &scroll_hint_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_scroll_hint_mode :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: Scroll_Container_Scroll_Hint_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scroll_hint_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 246835423)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_tile_scroll_hint :: proc "contextless" (
    self: Scroll_Container,
    tile_scroll_hint_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_scroll_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    tile_scroll_hint_ := tile_scroll_hint_
    args := []__bindgen_gde.TypePtr {
        &tile_scroll_hint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_is_scroll_hint_tiled :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_scroll_hint_tiled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_set_follow_focus :: proc "contextless" (
    self: Scroll_Container,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_follow_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_is_following_focus :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_following_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_get_h_scroll_bar :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: H_Scroll_Bar) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_scroll_bar", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4004517983)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_get_v_scroll_bar :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: V_Scroll_Bar) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_scroll_bar", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2630340773)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scroll_container_ensure_control_visible :: proc "contextless" (
    self: Scroll_Container,
    control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ensure_control_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    control_ := control_
    args := []__bindgen_gde.TypePtr {
        &control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_set_draw_focus_border :: proc "contextless" (
    self: Scroll_Container,
    draw_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_focus_border", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    draw_ := draw_
    args := []__bindgen_gde.TypePtr {
        &draw_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scroll_container_get_draw_focus_border :: proc "contextless" (
    self: Scroll_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_draw_focus_border", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
scroll_container_get_follow_focus :: proc "contextless" (self: Scroll_Container) -> Bool {
    return scroll_container_is_following_focus(self)
}
scroll_container_get_scroll_horizontal :: proc "contextless" (self: Scroll_Container) -> i32 {
    return scroll_container_get_h_scroll(self)
}
scroll_container_set_scroll_horizontal :: proc "contextless" (self: Scroll_Container, value: Int) {
    scroll_container_set_h_scroll(self, value)
}
scroll_container_get_scroll_vertical :: proc "contextless" (self: Scroll_Container) -> i32 {
    return scroll_container_get_v_scroll(self)
}
scroll_container_set_scroll_vertical :: proc "contextless" (self: Scroll_Container, value: Int) {
    scroll_container_set_v_scroll(self, value)
}
scroll_container_get_scroll_horizontal_custom_step :: proc "contextless" (self: Scroll_Container) -> f64 {
    return scroll_container_get_horizontal_custom_step(self)
}
scroll_container_set_scroll_horizontal_custom_step :: proc "contextless" (self: Scroll_Container, value: f64) {
    scroll_container_set_horizontal_custom_step(self, value)
}
scroll_container_get_scroll_vertical_custom_step :: proc "contextless" (self: Scroll_Container) -> f64 {
    return scroll_container_get_vertical_custom_step(self)
}
scroll_container_set_scroll_vertical_custom_step :: proc "contextless" (self: Scroll_Container, value: f64) {
    scroll_container_set_vertical_custom_step(self, value)
}
scroll_container_get_scroll_horizontal_by_default :: proc "contextless" (self: Scroll_Container) -> Bool {
    return scroll_container_is_scroll_horizontal_by_default(self)
}
scroll_container_get_scroll_deadzone :: proc "contextless" (self: Scroll_Container) -> i32 {
    return scroll_container_get_deadzone(self)
}
scroll_container_set_scroll_deadzone :: proc "contextless" (self: Scroll_Container, value: Int) {
    scroll_container_set_deadzone(self, value)
}
scroll_container_get_tile_scroll_hint :: proc "contextless" (self: Scroll_Container) -> Bool {
    return scroll_container_is_scroll_hint_tiled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
scroll_container_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ScrollContainer", true)
}

@(private = "file")
__class_name: String_Name