package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Spatial_Anchor_Capability_Constants :: enum {
}
Open_Xr_Spatial_Anchor_Capability_Persistence_Scope :: enum int {
    Persistence_Scope_System_Managed = 1,
    Persistence_Scope_Local_Anchors = 1000781000,
}



open_xr_spatial_anchor_capability_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_spatial_anchor_capability_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_spatial_anchor_capability :: proc "contextless" () -> Open_Xr_Spatial_Anchor_Capability {
    return __bindgen_gde.classdb_construct_object(open_xr_spatial_anchor_capability_name_ref())
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

open_xr_spatial_anchor_capability_is_spatial_anchor_supported :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_spatial_anchor_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_anchor_capability_is_spatial_persistence_supported :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_spatial_persistence_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_anchor_capability_is_persistence_scope_supported :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    scope_: Open_Xr_Spatial_Anchor_Capability_Persistence_Scope,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_persistence_scope_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3651771626)
    }
    self := self
    scope_ := scope_
    args := []__bindgen_gde.TypePtr {
        &scope_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_anchor_capability_create_persistence_context :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    scope_: Open_Xr_Spatial_Anchor_Capability_Persistence_Scope,
    user_callback_: Callable,
) -> (ret: Open_Xr_Future_Result) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_persistence_context", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 856276630)
    }
    self := self
    scope_ := scope_
    user_callback_ := user_callback_
    args := []__bindgen_gde.TypePtr {
        &scope_,
        &user_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_anchor_capability_get_persistence_context_handle :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    persistence_context_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_persistence_context_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    persistence_context_ := persistence_context_
    args := []__bindgen_gde.TypePtr {
        &persistence_context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_anchor_capability_free_persistence_context :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    persistence_context_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_persistence_context", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    persistence_context_ := persistence_context_
    args := []__bindgen_gde.TypePtr {
        &persistence_context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_spatial_anchor_capability_create_new_anchor :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    transform_: Transform3d,
    spatial_context_: Rid,
) -> (ret: Open_Xr_Anchor_Tracker) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_new_anchor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 607100373)
    }
    self := self
    transform_ := transform_
    spatial_context_ := spatial_context_
    args := []__bindgen_gde.TypePtr {
        &transform_,
        &spatial_context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_anchor_capability_remove_anchor :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    anchor_tracker_: Open_Xr_Anchor_Tracker,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_anchor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3579451518)
    }
    self := self
    anchor_tracker_ := anchor_tracker_
    args := []__bindgen_gde.TypePtr {
        &anchor_tracker_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_spatial_anchor_capability_persist_anchor :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    anchor_tracker_: Open_Xr_Anchor_Tracker,
    persistence_context_: Rid,
    user_callback_: Callable,
) -> (ret: Open_Xr_Future_Result) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("persist_anchor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4244202513)
    }
    self := self
    anchor_tracker_ := anchor_tracker_
    persistence_context_ := persistence_context_
    user_callback_ := user_callback_
    args := []__bindgen_gde.TypePtr {
        &anchor_tracker_,
        &persistence_context_,
        &user_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_anchor_capability_unpersist_anchor :: proc "contextless" (
    self: Open_Xr_Spatial_Anchor_Capability,
    anchor_tracker_: Open_Xr_Anchor_Tracker,
    persistence_context_: Rid,
    user_callback_: Callable,
) -> (ret: Open_Xr_Future_Result) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unpersist_anchor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4244202513)
    }
    self := self
    anchor_tracker_ := anchor_tracker_
    persistence_context_ := persistence_context_
    user_callback_ := user_callback_
    args := []__bindgen_gde.TypePtr {
        &anchor_tracker_,
        &persistence_context_,
        &user_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_spatial_anchor_capability_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRSpatialAnchorCapability", true)
}

@(private = "file")
__class_name: String_Name