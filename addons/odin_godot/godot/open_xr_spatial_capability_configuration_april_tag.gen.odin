package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Spatial_Capability_Configuration_April_Tag_Constants :: enum {
}
Open_Xr_Spatial_Capability_Configuration_April_Tag_April_Tag_Dict :: enum int {
    April_Tag_Dict_16h5 = 1,
    April_Tag_Dict_25h9 = 2,
    April_Tag_Dict_36h10 = 3,
    April_Tag_Dict_36h11 = 4,
}



open_xr_spatial_capability_configuration_april_tag_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_spatial_capability_configuration_april_tag_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_spatial_capability_configuration_april_tag :: proc "contextless" () -> Open_Xr_Spatial_Capability_Configuration_April_Tag {
    return cast(Open_Xr_Spatial_Capability_Configuration_April_Tag)__bindgen_gde.classdb_construct_object(open_xr_spatial_capability_configuration_april_tag_name_ref())
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

open_xr_spatial_capability_configuration_april_tag_get_enabled_components :: proc "contextless" (
    self: Open_Xr_Spatial_Capability_Configuration_April_Tag,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_enabled_components", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 235988956)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_capability_configuration_april_tag_set_april_dict :: proc "contextless" (
    self: Open_Xr_Spatial_Capability_Configuration_April_Tag,
    april_dict_: Open_Xr_Spatial_Capability_Configuration_April_Tag_April_Tag_Dict,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_april_dict", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3902905799)
    }
    self := self
    april_dict_ := april_dict_
    args := []__bindgen_gde.TypePtr {
        &april_dict_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_spatial_capability_configuration_april_tag_get_april_dict :: proc "contextless" (
    self: Open_Xr_Spatial_Capability_Configuration_April_Tag,
) -> (ret: Open_Xr_Spatial_Capability_Configuration_April_Tag_April_Tag_Dict) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_april_dict", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 440273016)
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
open_xr_spatial_capability_configuration_april_tag_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRSpatialCapabilityConfigurationAprilTag", true)
}

@(private = "file")
__class_name: String_Name