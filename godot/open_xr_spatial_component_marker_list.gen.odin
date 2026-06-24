package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Spatial_Component_Marker_List_Constants :: enum {
}
Open_Xr_Spatial_Component_Marker_List_Marker_Type :: enum int {
    Marker_Type_Unknown = 0,
    Marker_Type_Qrcode = 1,
    Marker_Type_Micro_Qrcode = 2,
    Marker_Type_Aruco = 3,
    Marker_Type_April_Tag = 4,
    Marker_Type_Max = 5,
}



open_xr_spatial_component_marker_list_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_spatial_component_marker_list_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_spatial_component_marker_list :: proc "contextless" () -> Open_Xr_Spatial_Component_Marker_List {
    return cast(Open_Xr_Spatial_Component_Marker_List)__bindgen_gde.classdb_construct_object(open_xr_spatial_component_marker_list_name_ref())
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

open_xr_spatial_component_marker_list_get_marker_type :: proc "contextless" (
    self: Open_Xr_Spatial_Component_Marker_List,
    index_: Int,
) -> (ret: Open_Xr_Spatial_Component_Marker_List_Marker_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2627847866)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_component_marker_list_get_marker_id :: proc "contextless" (
    self: Open_Xr_Spatial_Component_Marker_List,
    index_: Int,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_component_marker_list_get_marker_data :: proc "contextless" (
    self: Open_Xr_Spatial_Component_Marker_List,
    snapshot_: Rid,
    index_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4069510997)
    }
    self := self
    snapshot_ := snapshot_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &snapshot_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_spatial_component_marker_list_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRSpatialComponentMarkerList", true)
}

@(private = "file")
__class_name: String_Name