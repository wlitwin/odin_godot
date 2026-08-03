package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Spatial_Entity_Extension_Constants :: enum {
}
Open_Xr_Spatial_Entity_Extension_Capability :: enum int {
    Capability_Plane_Tracking = 1000741000,
    Capability_Marker_Tracking_Qr_Code = 1000743000,
    Capability_Marker_Tracking_Micro_Qr_Code = 1000743001,
    Capability_Marker_Tracking_Aruco_Marker = 1000743002,
    Capability_Marker_Tracking_April_Tag = 1000743003,
    Capability_Anchor = 1000762000,
}
Open_Xr_Spatial_Entity_Extension_Component_Type :: enum int {
    Component_Type_Bounded_2d = 1,
    Component_Type_Bounded_3d = 2,
    Component_Type_Parent = 3,
    Component_Type_Mesh_3d = 4,
    Component_Type_Plane_Alignment = 1000741000,
    Component_Type_Mesh_2d = 1000741001,
    Component_Type_Polygon_2d = 1000741002,
    Component_Type_Plane_Semantic_Label = 1000741003,
    Component_Type_Marker = 1000743000,
    Component_Type_Anchor = 1000762000,
    Component_Type_Persistence = 1000763000,
}



open_xr_spatial_entity_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_spatial_entity_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_spatial_entity_extension :: proc "contextless" () -> Open_Xr_Spatial_Entity_Extension {
    return cast(Open_Xr_Spatial_Entity_Extension)__bindgen_gde.classdb_construct_object(open_xr_spatial_entity_extension_name_ref())
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

open_xr_spatial_entity_extension_supports_capability :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    capability_: Open_Xr_Spatial_Entity_Extension_Capability,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("supports_capability", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1940837202)
    }
    self := self
    capability_ := capability_
    args := []__bindgen_gde.TypePtr {
        &capability_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_supports_component_type :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    capability_: Open_Xr_Spatial_Entity_Extension_Capability,
    component_type_: Open_Xr_Spatial_Entity_Extension_Component_Type,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("supports_component_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 26842779)
    }
    self := self
    capability_ := capability_
    component_type_ := component_type_
    args := []__bindgen_gde.TypePtr {
        &capability_,
        &component_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_create_spatial_context :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    capability_configurations_: Typed_Array(Open_Xr_Spatial_Capability_Configuration_Base_Header),
    next_: Open_Xr_Structure_Base,
    user_callback_: Callable,
) -> (ret: Open_Xr_Future_Result) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_spatial_context", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1874506473)
    }
    self := self
    capability_configurations_ := capability_configurations_
    next_ := next_
    user_callback_ := user_callback_
    args := []__bindgen_gde.TypePtr {
        &capability_configurations_,
        &next_,
        &user_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_spatial_context_ready :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spatial_context_ready", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    spatial_context_ := spatial_context_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_free_spatial_context :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_spatial_context", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    spatial_context_ := spatial_context_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_spatial_entity_extension_get_spatial_context_handle :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spatial_context_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    spatial_context_ := spatial_context_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_discover_spatial_entities_with_component_data :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
    component_data_: Typed_Array(Open_Xr_Spatial_Component_Data),
    next_: Open_Xr_Structure_Base,
    user_callback_: Callable,
) -> (ret: Open_Xr_Future_Result) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("discover_spatial_entities_with_component_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1830928590)
    }
    self := self
    spatial_context_ := spatial_context_
    component_data_ := component_data_
    next_ := next_
    user_callback_ := user_callback_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
        &component_data_,
        &next_,
        &user_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_discover_spatial_entities :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
    component_types_: Packed_Int64_Array,
    next_: Open_Xr_Structure_Base,
    user_callback_: Callable,
) -> (ret: Open_Xr_Future_Result) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("discover_spatial_entities", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2252833536)
    }
    self := self
    spatial_context_ := spatial_context_
    component_types_ := component_types_
    next_ := next_
    user_callback_ := user_callback_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
        &component_types_,
        &next_,
        &user_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_update_spatial_entities :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
    entities_: Typed_Array(Rid),
    component_types_: Packed_Int64_Array,
    next_: Open_Xr_Structure_Base,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_spatial_entities", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3446086438)
    }
    self := self
    spatial_context_ := spatial_context_
    entities_ := entities_
    component_types_ := component_types_
    next_ := next_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
        &entities_,
        &component_types_,
        &next_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_free_spatial_snapshot :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_spatial_snapshot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_spatial_entity_extension_get_spatial_snapshot_handle :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spatial_snapshot_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_spatial_snapshot_context :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spatial_snapshot_context", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814569979)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_query_snapshot :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    component_data_: Typed_Array(Open_Xr_Spatial_Component_Data),
    next_: Open_Xr_Structure_Base,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("query_snapshot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 641015484)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    component_data_ := component_data_
    next_ := next_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &component_data_,
        &next_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_string :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    buffer_id_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1464764419)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    buffer_id_ := buffer_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &buffer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_uint8_buffer :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    buffer_id_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uint8_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3570600051)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    buffer_id_ := buffer_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &buffer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_uint16_buffer :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    buffer_id_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uint16_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3393655756)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    buffer_id_ := buffer_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &buffer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_uint32_buffer :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    buffer_id_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uint32_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3393655756)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    buffer_id_ := buffer_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &buffer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_float_buffer :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    buffer_id_: Int,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_float_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2313216651)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    buffer_id_ := buffer_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &buffer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_vector2_buffer :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    buffer_id_: Int,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vector2_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 110850971)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    buffer_id_ := buffer_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &buffer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_vector3_buffer :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_snapshot_: Rid,
    buffer_id_: Int,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vector3_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1166453791)
    }
    self := self
    spatial_snapshot_ := spatial_snapshot_
    buffer_id_ := buffer_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_snapshot_,
        &buffer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_find_spatial_entity :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    entity_id_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_spatial_entity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 937000113)
    }
    self := self
    entity_id_ := entity_id_
    args := []__bindgen_gde.TypePtr {
        &entity_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_add_spatial_entity :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
    entity_id_: Int,
    entity_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_spatial_entity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2256026069)
    }
    self := self
    spatial_context_ := spatial_context_
    entity_id_ := entity_id_
    entity_ := entity_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
        &entity_id_,
        &entity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_make_spatial_entity :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    spatial_context_: Rid,
    entity_id_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_spatial_entity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2233757277)
    }
    self := self
    spatial_context_ := spatial_context_
    entity_id_ := entity_id_
    args := []__bindgen_gde.TypePtr {
        &spatial_context_,
        &entity_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_spatial_entity_id :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    entity_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spatial_entity_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    entity_ := entity_
    args := []__bindgen_gde.TypePtr {
        &entity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_get_spatial_entity_context :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    entity_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spatial_entity_context", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814569979)
    }
    self := self
    entity_ := entity_
    args := []__bindgen_gde.TypePtr {
        &entity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_spatial_entity_extension_free_spatial_entity :: proc "contextless" (
    self: Open_Xr_Spatial_Entity_Extension,
    entity_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_spatial_entity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    entity_ := entity_
    args := []__bindgen_gde.TypePtr {
        &entity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_spatial_entity_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRSpatialEntityExtension", true)
}

@(private = "file")
__class_name: String_Name