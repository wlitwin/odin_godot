package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Plane_Tracker_Constants :: enum {
}



open_xr_plane_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_plane_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_plane_tracker :: proc "contextless" () -> Open_Xr_Plane_Tracker {
    return cast(Open_Xr_Plane_Tracker)__bindgen_gde.classdb_construct_object(open_xr_plane_tracker_name_ref())
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

open_xr_plane_tracker_set_bounds_size :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
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

open_xr_plane_tracker_get_bounds_size :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
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

open_xr_plane_tracker_set_plane_alignment :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
    plane_alignment_: Open_Xr_Spatial_Component_Plane_Alignment_List_Plane_Alignment,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_plane_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1214382230)
    }
    self := self
    plane_alignment_ := plane_alignment_
    args := []__bindgen_gde.TypePtr {
        &plane_alignment_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_plane_tracker_get_plane_alignment :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
) -> (ret: Open_Xr_Spatial_Component_Plane_Alignment_List_Plane_Alignment) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_plane_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 845541441)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_plane_tracker_set_plane_label :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
    plane_label_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_plane_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    plane_label_ := plane_label_
    args := []__bindgen_gde.TypePtr {
        &plane_label_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_plane_tracker_get_plane_label :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_plane_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_plane_tracker_set_mesh_data :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
    origin_: Transform3d,
    vertices_: Packed_Vector2_Array,
    indices_: Packed_Int32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mesh_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1877193149)
    }
    self := self
    origin_ := origin_
    vertices_ := vertices_
    indices_ := indices_
    args := []__bindgen_gde.TypePtr {
        &origin_,
        &vertices_,
        &indices_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_plane_tracker_clear_mesh_data :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_mesh_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_plane_tracker_get_mesh_offset :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229777777)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_plane_tracker_get_mesh :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
) -> (ret: Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4081188045)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_plane_tracker_get_shape :: proc "contextless" (
    self: Open_Xr_Plane_Tracker,
    thickness_: f64,
) -> (ret: Shape3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3358509884)
    }
    self := self
    thickness_ := thickness_
    args := []__bindgen_gde.TypePtr {
        &thickness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_plane_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRPlaneTracker", true)
}

@(private = "file")
__class_name: String_Name