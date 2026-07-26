package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Spatial_Plane_Tracking_Capability_Constants :: enum {
}



open_xr_spatial_plane_tracking_capability_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_spatial_plane_tracking_capability_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_spatial_plane_tracking_capability :: proc "contextless" () -> Open_Xr_Spatial_Plane_Tracking_Capability {
    return __bindgen_gde.classdb_construct_object(open_xr_spatial_plane_tracking_capability_name_ref())
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

open_xr_spatial_plane_tracking_capability_is_supported :: proc "contextless" (
    self: Open_Xr_Spatial_Plane_Tracking_Capability,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_plane_tracking_capability_start_entity_discovery :: proc "contextless" (
    self: Open_Xr_Spatial_Plane_Tracking_Capability,
    spatial_context_: Rid,
    component_data_: Typed_Array(Open_Xr_Spatial_Component_Data),
    next_snapshot_create_: Open_Xr_Structure_Base,
    next_snapshot_query_: Open_Xr_Structure_Base,
    user_callback_: Callable,
) -> (ret: Open_Xr_Future_Result) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_entity_discovery", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3452714169)
    }
    self := self
    spatial_context_ := spatial_context_
    component_data_ := component_data_
    next_snapshot_create_ := next_snapshot_create_
    next_snapshot_query_ := next_snapshot_query_
    user_callback_ := user_callback_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
        &component_data_,
        &next_snapshot_create_,
        &next_snapshot_query_,
        &user_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_spatial_plane_tracking_capability_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRSpatialPlaneTrackingCapability", true)
}

@(private = "file")
__class_name: String_Name