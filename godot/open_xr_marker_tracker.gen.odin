package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Marker_Tracker_Constants :: enum {
}



open_xr_marker_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_marker_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_marker_tracker :: proc "contextless" () -> Open_Xr_Marker_Tracker {
    return cast(Open_Xr_Marker_Tracker)__bindgen_gde.classdb_construct_object(open_xr_marker_tracker_name_ref())
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

open_xr_marker_tracker_set_bounds_size :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
    bounds_size_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bounds_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    bounds_size_ := bounds_size_
    args := []__bindgen_gde.TypePtr {
        &bounds_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_marker_tracker_get_bounds_size :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bounds_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_marker_tracker_set_marker_type :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
    marker_type_: Open_Xr_Spatial_Component_Marker_List_Marker_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_marker_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2156241362)
    }
    self := self
    marker_type_ := marker_type_
    args := []__bindgen_gde.TypePtr {
        &marker_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_marker_tracker_get_marker_type :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
) -> (ret: Open_Xr_Spatial_Component_Marker_List_Marker_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 612702862)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_marker_tracker_set_marker_id :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
    marker_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_marker_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    marker_id_ := marker_id_
    args := []__bindgen_gde.TypePtr {
        &marker_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_marker_tracker_get_marker_id :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_marker_tracker_set_marker_data :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
    marker_data_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_marker_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1114965689)
    }
    self := self
    marker_data_ := marker_data_
    args := []__bindgen_gde.TypePtr {
        &marker_data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_marker_tracker_get_marker_data :: proc "contextless" (
    self: Open_Xr_Marker_Tracker,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1214101251)
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
open_xr_marker_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRMarkerTracker", true)
}

@(private = "file")
__class_name: String_Name