package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Spatial_Entity_Tracker_Constants :: enum {
}
Open_Xr_Spatial_Entity_Tracker_Entity_Tracking_State :: enum int {
    Entity_Tracking_State_Stopped = 1,
    Entity_Tracking_State_Paused = 2,
    Entity_Tracking_State_Tracking = 3,
}



open_xr_spatial_entity_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_spatial_entity_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_spatial_entity_tracker :: proc "contextless" () -> Open_Xr_Spatial_Entity_Tracker {
    return cast(Open_Xr_Spatial_Entity_Tracker)__bindgen_gde.classdb_construct_object(open_xr_spatial_entity_tracker_name_ref())
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

open_xr_spatial_entity_tracker_set_entity :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Tracker,
    entity_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_entity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    entity_ := entity_
    args := []__bindgen_gde.TypePtr {
        &entity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_spatial_entity_tracker_get_entity :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Tracker,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_entity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_tracker_set_spatial_tracking_state :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Tracker,
    spatial_tracking_state_: Open_Xr_Spatial_Entity_Tracker_Entity_Tracking_State,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_spatial_tracking_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2170234447)
    }
    self := self
    spatial_tracking_state_ := spatial_tracking_state_
    args := []__bindgen_gde.TypePtr {
        &spatial_tracking_state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_spatial_entity_tracker_get_spatial_tracking_state :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Tracker,
) -> (ret: Open_Xr_Spatial_Entity_Tracker_Entity_Tracking_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spatial_tracking_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3351876560)
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
open_xr_spatial_entity_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRSpatialEntityTracker", true)
}

@(private = "file")
__class_name: String_Name