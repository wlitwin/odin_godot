package godot

import __bindgen_gde "godot:gdext"

Grid_Map_Constants :: enum {
    INVALID_CELL_ITEM = -1,
}
Grid_Map_Debug_Visibility_Mode :: enum int {
    Debug_Visibility_Mode_Default = 0,
    Debug_Visibility_Mode_Force_Show = 1,
    Debug_Visibility_Mode_Force_Hide = 2,
}



grid_map_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

grid_map_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_grid_map :: proc "contextless" () -> Grid_Map {
    return cast(Grid_Map)__bindgen_gde.classdb_construct_object(grid_map_name_ref())
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

grid_map_set_collision_layer :: proc "contextless" (
    self: Grid_Map,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_collision_layer :: proc "contextless" (
    self: Grid_Map,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_collision_mask :: proc "contextless" (
    self: Grid_Map,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_collision_mask :: proc "contextless" (
    self: Grid_Map,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_collision_mask_value :: proc "contextless" (
    self: Grid_Map,
    layer_number_: Int,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_mask_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_number_ := layer_number_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_collision_mask_value :: proc "contextless" (
    self: Grid_Map,
    layer_number_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_mask_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_number_ := layer_number_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_collision_layer_value :: proc "contextless" (
    self: Grid_Map,
    layer_number_: Int,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_layer_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_number_ := layer_number_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_collision_layer_value :: proc "contextless" (
    self: Grid_Map,
    layer_number_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_layer_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_number_ := layer_number_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_collision_priority :: proc "contextless" (
    self: Grid_Map,
    priority_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    priority_ := priority_
    args := []__bindgen_gde.TypePtr {
        &priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_collision_priority :: proc "contextless" (
    self: Grid_Map,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_collision_visibility_mode :: proc "contextless" (
    self: Grid_Map,
    visibility_mode_: Grid_Map_Debug_Visibility_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4160694578)
    }
    self := self
    visibility_mode_ := visibility_mode_
    args := []__bindgen_gde.TypePtr {
        &visibility_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_collision_visibility_mode :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Grid_Map_Debug_Visibility_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3729798365)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_physics_material :: proc "contextless" (
    self: Grid_Map,
    material_: Physics_Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1784508650)
    }
    self := self
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_physics_material :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Physics_Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2521850424)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_bake_navigation :: proc "contextless" (
    self: Grid_Map,
    bake_navigation_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bake_navigation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    bake_navigation_ := bake_navigation_
    args := []__bindgen_gde.TypePtr {
        &bake_navigation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_is_baking_navigation :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_baking_navigation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_navigation_map :: proc "contextless" (
    self: Grid_Map,
    navigation_map_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_navigation_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    navigation_map_ := navigation_map_
    args := []__bindgen_gde.TypePtr {
        &navigation_map_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_navigation_map :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_mesh_library :: proc "contextless" (
    self: Grid_Map,
    mesh_library_: Mesh_Library,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mesh_library", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1488083439)
    }
    self := self
    mesh_library_ := mesh_library_
    args := []__bindgen_gde.TypePtr {
        &mesh_library_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_mesh_library :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Mesh_Library) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh_library", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3350993772)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_cell_size :: proc "contextless" (
    self: Grid_Map,
    size_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cell_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_cell_size :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_cell_scale :: proc "contextless" (
    self: Grid_Map,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cell_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_cell_scale :: proc "contextless" (
    self: Grid_Map,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_octant_size :: proc "contextless" (
    self: Grid_Map,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_octant_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_octant_size :: proc "contextless" (
    self: Grid_Map,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_octant_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_cell_item :: proc "contextless" (
    self: Grid_Map,
    position_: Vector3i,
    item_: Int,
    orientation_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cell_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3449088946)
    }
    self := self
    position_ := position_
    item_ := item_
    orientation_ := orientation_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &item_,
        &orientation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_cell_item :: proc "contextless" (
    self: Grid_Map,
    position_: Vector3i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3724960147)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_cell_item_orientation :: proc "contextless" (
    self: Grid_Map,
    position_: Vector3i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_item_orientation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3724960147)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_cell_item_basis :: proc "contextless" (
    self: Grid_Map,
    position_: Vector3i,
) -> (ret: Basis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_item_basis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3493604918)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_basis_with_orthogonal_index :: proc "contextless" (
    self: Grid_Map,
    index_: Int,
) -> (ret: Basis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_basis_with_orthogonal_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2816196998)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_orthogonal_index_from_basis :: proc "contextless" (
    self: Grid_Map,
    basis_: Basis,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_orthogonal_index_from_basis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4210359952)
    }
    self := self
    basis_ := basis_
    args := []__bindgen_gde.TypePtr {
        &basis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_local_to_map :: proc "contextless" (
    self: Grid_Map,
    local_position_: Vector3,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("local_to_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1257687843)
    }
    self := self
    local_position_ := local_position_
    args := []__bindgen_gde.TypePtr {
        &local_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_map_to_local :: proc "contextless" (
    self: Grid_Map,
    map_position_: Vector3i,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("map_to_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1088329196)
    }
    self := self
    map_position_ := map_position_
    args := []__bindgen_gde.TypePtr {
        &map_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_resource_changed :: proc "contextless" (
    self: Grid_Map,
    resource_: Resource,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resource_changed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 968641751)
    }
    self := self
    resource_ := resource_
    args := []__bindgen_gde.TypePtr {
        &resource_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_set_center_x :: proc "contextless" (
    self: Grid_Map,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_center_x :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_center_y :: proc "contextless" (
    self: Grid_Map,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_center_y :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_set_center_z :: proc "contextless" (
    self: Grid_Map,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_center_z :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_clear :: proc "contextless" (
    self: Grid_Map,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_get_used_cells :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_cells", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_used_cells_by_item :: proc "contextless" (
    self: Grid_Map,
    item_: Int,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_cells_by_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 663333327)
    }
    self := self
    item_ := item_
    args := []__bindgen_gde.TypePtr {
        &item_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_used_octants :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_octants", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_used_octants_by_item :: proc "contextless" (
    self: Grid_Map,
    item_: Int,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_octants_by_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 663333327)
    }
    self := self
    item_ := item_
    args := []__bindgen_gde.TypePtr {
        &item_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_used_cells_in_octant :: proc "contextless" (
    self: Grid_Map,
    octant_coords_: Vector3i,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_cells_in_octant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658725580)
    }
    self := self
    octant_coords_ := octant_coords_
    args := []__bindgen_gde.TypePtr {
        &octant_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_used_cells_in_octant_by_item :: proc "contextless" (
    self: Grid_Map,
    octant_coords_: Vector3i,
    item_: Int,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_cells_in_octant_by_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2384667821)
    }
    self := self
    octant_coords_ := octant_coords_
    item_ := item_
    args := []__bindgen_gde.TypePtr {
        &octant_coords_,
        &item_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_octants_in_bounds :: proc "contextless" (
    self: Grid_Map,
    bounds_: Aabb,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_octants_in_bounds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2489849902)
    }
    self := self
    bounds_ := bounds_
    args := []__bindgen_gde.TypePtr {
        &bounds_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_used_octants_in_bounds :: proc "contextless" (
    self: Grid_Map,
    bounds_: Aabb,
) -> (ret: Typed_Array(Vector3i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_octants_in_bounds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2489849902)
    }
    self := self
    bounds_ := bounds_
    args := []__bindgen_gde.TypePtr {
        &bounds_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_octant_coords_from_cell_coords :: proc "contextless" (
    self: Grid_Map,
    cell_coords_: Vector3i,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_octant_coords_from_cell_coords", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2075501597)
    }
    self := self
    cell_coords_ := cell_coords_
    args := []__bindgen_gde.TypePtr {
        &cell_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_meshes :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_meshes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_bake_meshes :: proc "contextless" (
    self: Grid_Map,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bake_meshes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_get_bake_mesh_instance :: proc "contextless" (
    self: Grid_Map,
    idx_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bake_mesh_instance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 937000113)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_clear_baked_meshes :: proc "contextless" (
    self: Grid_Map,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_baked_meshes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_make_baked_meshes :: proc "contextless" (
    self: Grid_Map,
    gen_lightmap_uv_: Bool,
    lightmap_uv_texel_size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_baked_meshes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3609286057)
    }
    self := self
    gen_lightmap_uv_ := gen_lightmap_uv_
    lightmap_uv_texel_size_ := lightmap_uv_texel_size_
    args := []__bindgen_gde.TypePtr {
        &gen_lightmap_uv_,
        &lightmap_uv_texel_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
grid_map_get_cell_octant_size :: proc "contextless" (self: Grid_Map) -> i32 {
    return grid_map_get_octant_size(self)
}
grid_map_set_cell_octant_size :: proc "contextless" (self: Grid_Map, value: Int) {
    grid_map_set_octant_size(self, value)
}
grid_map_get_cell_center_x :: proc "contextless" (self: Grid_Map) -> Bool {
    return grid_map_get_center_x(self)
}
grid_map_set_cell_center_x :: proc "contextless" (self: Grid_Map, value: Bool) {
    grid_map_set_center_x(self, value)
}
grid_map_get_cell_center_y :: proc "contextless" (self: Grid_Map) -> Bool {
    return grid_map_get_center_y(self)
}
grid_map_set_cell_center_y :: proc "contextless" (self: Grid_Map, value: Bool) {
    grid_map_set_center_y(self, value)
}
grid_map_get_cell_center_z :: proc "contextless" (self: Grid_Map) -> Bool {
    return grid_map_get_center_z(self)
}
grid_map_set_cell_center_z :: proc "contextless" (self: Grid_Map, value: Bool) {
    grid_map_set_center_z(self, value)
}
grid_map_get_bake_navigation :: proc "contextless" (self: Grid_Map) -> Bool {
    return grid_map_is_baking_navigation(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
grid_map_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GridMap", true)
}

@(private = "file")
__class_name: String_Name