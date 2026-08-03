package godot

import __bindgen_gde "godot:gdext"

Voxel_Gi_Constants :: enum {
}
Voxel_Gi_Subdiv :: enum int {
    Subdiv_64 = 0,
    Subdiv_128 = 1,
    Subdiv_256 = 2,
    Subdiv_512 = 3,
    Subdiv_Max = 4,
}



voxel_gi_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

voxel_gi_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_voxel_gi :: proc "contextless" () -> Voxel_Gi {
    return cast(Voxel_Gi)__bindgen_gde.classdb_construct_object(voxel_gi_name_ref())
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

voxel_gi_set_probe_data :: proc "contextless" (
    self: Voxel_Gi,
    data_: Voxel_Gi_Data,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_probe_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1637849675)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

voxel_gi_get_probe_data :: proc "contextless" (
    self: Voxel_Gi,
) -> (ret: Voxel_Gi_Data) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_probe_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1730645405)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

voxel_gi_set_subdiv :: proc "contextless" (
    self: Voxel_Gi,
    subdiv_: Voxel_Gi_Subdiv,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_subdiv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240898472)
    }
    self := self
    subdiv_ := subdiv_
    args := []__bindgen_gde.TypePtr {
        &subdiv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

voxel_gi_get_subdiv :: proc "contextless" (
    self: Voxel_Gi,
) -> (ret: Voxel_Gi_Subdiv) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_subdiv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4261647950)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

voxel_gi_set_size :: proc "contextless" (
    self: Voxel_Gi,
    size_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

voxel_gi_get_size :: proc "contextless" (
    self: Voxel_Gi,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

voxel_gi_set_camera_attributes :: proc "contextless" (
    self: Voxel_Gi,
    camera_attributes_: Camera_Attributes,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_camera_attributes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2817810567)
    }
    self := self
    camera_attributes_ := camera_attributes_
    args := []__bindgen_gde.TypePtr {
        &camera_attributes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

voxel_gi_get_camera_attributes :: proc "contextless" (
    self: Voxel_Gi,
) -> (ret: Camera_Attributes) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_attributes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3921283215)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

voxel_gi_bake :: proc "contextless" (
    self: Voxel_Gi,
    from_node_: Node,
    create_visual_debug_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bake", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2781551026)
    }
    self := self
    from_node_ := from_node_
    create_visual_debug_ := create_visual_debug_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &create_visual_debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

voxel_gi_debug_bake :: proc "contextless" (
    self: Voxel_Gi,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("debug_bake", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
voxel_gi_get_data :: proc "contextless" (self: Voxel_Gi) -> Voxel_Gi_Data {
    return voxel_gi_get_probe_data(self)
}
voxel_gi_set_data :: proc "contextless" (self: Voxel_Gi, value: Voxel_Gi_Data) {
    voxel_gi_set_probe_data(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
voxel_gi_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VoxelGI", true)
}

@(private = "file")
__class_name: String_Name