package godot

import __bindgen_gde "godot:gdext"

Xr_Tracker_Constants :: enum {
}



xr_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_tracker :: proc "contextless" () -> Xr_Tracker {
    return cast(Xr_Tracker)__bindgen_gde.classdb_construct_object(xr_tracker_name_ref())
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

xr_tracker_get_tracker_type :: proc "contextless" (
    self: Xr_Tracker,
) -> (ret: Xr_Server_Tracker_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracker_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2784508102)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_tracker_set_tracker_type :: proc "contextless" (
    self: Xr_Tracker,
    type_: Xr_Server_Tracker_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tracker_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3055763575)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_tracker_get_tracker_name :: proc "contextless" (
    self: Xr_Tracker,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracker_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_tracker_set_tracker_name :: proc "contextless" (
    self: Xr_Tracker,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tracker_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_tracker_get_tracker_desc :: proc "contextless" (
    self: Xr_Tracker,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracker_desc", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_tracker_set_tracker_desc :: proc "contextless" (
    self: Xr_Tracker,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tracker_desc", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
xr_tracker_get_type :: proc "contextless" (self: Xr_Tracker) -> Xr_Server_Tracker_Type {
    return xr_tracker_get_tracker_type(self)
}
xr_tracker_set_type :: proc "contextless" (self: Xr_Tracker, value: Xr_Server_Tracker_Type) {
    xr_tracker_set_tracker_type(self, value)
}
xr_tracker_get_name :: proc "contextless" (self: Xr_Tracker) -> String_Name {
    return xr_tracker_get_tracker_name(self)
}
xr_tracker_set_name :: proc "contextless" (self: Xr_Tracker, value: String_Name) {
    xr_tracker_set_tracker_name(self, value)
}
xr_tracker_get_description :: proc "contextless" (self: Xr_Tracker) -> String {
    return xr_tracker_get_tracker_desc(self)
}
xr_tracker_set_description :: proc "contextless" (self: Xr_Tracker, value: String) {
    xr_tracker_set_tracker_desc(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
xr_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRTracker", true)
}

@(private = "file")
__class_name: String_Name