package godot

import __bindgen_gde "godot:gdext"

Flow_Container_Constants :: enum {
}
Flow_Container_Alignment_Mode :: enum int {
    Alignment_Begin = 0,
    Alignment_Center = 1,
    Alignment_End = 2,
}
Flow_Container_Last_Wrap_Alignment_Mode :: enum int {
    Last_Wrap_Alignment_Inherit = 0,
    Last_Wrap_Alignment_Begin = 1,
    Last_Wrap_Alignment_Center = 2,
    Last_Wrap_Alignment_End = 3,
}



flow_container_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

flow_container_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_flow_container :: proc "contextless" () -> Flow_Container {
    return __bindgen_gde.classdb_construct_object(flow_container_name_ref())
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

flow_container_get_line_count :: proc "contextless" (
    self: Flow_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

flow_container_set_alignment :: proc "contextless" (
    self: Flow_Container,
    alignment_: Flow_Container_Alignment_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 575250951)
    }
    self := self
    alignment_ := alignment_
    args := []__bindgen_gde.TypePtr {
        &alignment_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

flow_container_get_alignment :: proc "contextless" (
    self: Flow_Container,
) -> (ret: Flow_Container_Alignment_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3749743559)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

flow_container_set_last_wrap_alignment :: proc "contextless" (
    self: Flow_Container,
    last_wrap_alignment_: Flow_Container_Last_Wrap_Alignment_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_last_wrap_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2899697495)
    }
    self := self
    last_wrap_alignment_ := last_wrap_alignment_
    args := []__bindgen_gde.TypePtr {
        &last_wrap_alignment_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

flow_container_get_last_wrap_alignment :: proc "contextless" (
    self: Flow_Container,
) -> (ret: Flow_Container_Last_Wrap_Alignment_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_last_wrap_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3743456014)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

flow_container_set_vertical :: proc "contextless" (
    self: Flow_Container,
    vertical_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertical", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    vertical_ := vertical_
    args := []__bindgen_gde.TypePtr {
        &vertical_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

flow_container_is_vertical :: proc "contextless" (
    self: Flow_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_vertical", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

flow_container_set_reverse_fill :: proc "contextless" (
    self: Flow_Container,
    reverse_fill_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_reverse_fill", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    reverse_fill_ := reverse_fill_
    args := []__bindgen_gde.TypePtr {
        &reverse_fill_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

flow_container_is_reverse_fill :: proc "contextless" (
    self: Flow_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_reverse_fill", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
flow_container_get_vertical :: proc "contextless" (self: Flow_Container) -> Bool {
    return flow_container_is_vertical(self)
}
flow_container_get_reverse_fill :: proc "contextless" (self: Flow_Container) -> Bool {
    return flow_container_is_reverse_fill(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
flow_container_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("FlowContainer", true)
}

@(private = "file")
__class_name: String_Name