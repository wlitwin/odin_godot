package godot

import __bindgen_gde "godot:gdext"

Navigation_Path_Query_Parameters2d_Constants :: enum {
}
Navigation_Path_Query_Parameters2d_Pathfinding_Algorithm :: enum int {
    Pathfinding_Algorithm_Astar = 0,
}
Navigation_Path_Query_Parameters2d_Path_Post_Processing :: enum int {
    Path_Postprocessing_Corridorfunnel = 0,
    Path_Postprocessing_Edgecentered = 1,
    Path_Postprocessing_None = 2,
}

Navigation_Path_Query_Parameters2d_Path_Metadata_Flags :: enum i64 {
    Path_Metadata_Include_None = 0,
    Path_Metadata_Include_Types = 1,
    Path_Metadata_Include_Rids = 2,
    Path_Metadata_Include_Owners = 4,
    Path_Metadata_Include_All = 7,
}


navigation_path_query_parameters2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

navigation_path_query_parameters2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_navigation_path_query_parameters2d :: proc "contextless" () -> Navigation_Path_Query_Parameters2d {
    return cast(Navigation_Path_Query_Parameters2d)__bindgen_gde.classdb_construct_object(navigation_path_query_parameters2d_name_ref())
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

navigation_path_query_parameters2d_set_pathfinding_algorithm :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    pathfinding_algorithm_: Navigation_Path_Query_Parameters2d_Pathfinding_Algorithm,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pathfinding_algorithm", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2783519915)
    }
    self := self
    pathfinding_algorithm_ := pathfinding_algorithm_
    args := []__bindgen_gde.TypePtr {
        &pathfinding_algorithm_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_pathfinding_algorithm :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Navigation_Path_Query_Parameters2d_Pathfinding_Algorithm) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pathfinding_algorithm", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3000421146)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_path_postprocessing :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    path_postprocessing_: Navigation_Path_Query_Parameters2d_Path_Post_Processing,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_postprocessing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2864409082)
    }
    self := self
    path_postprocessing_ := path_postprocessing_
    args := []__bindgen_gde.TypePtr {
        &path_postprocessing_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_path_postprocessing :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Navigation_Path_Query_Parameters2d_Path_Post_Processing) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_postprocessing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3798118993)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_map :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    map_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    map_ := map_
    args := []__bindgen_gde.TypePtr {
        &map_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_map :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_start_position :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    start_position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_start_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    start_position_ := start_position_
    args := []__bindgen_gde.TypePtr {
        &start_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_start_position :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_start_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_target_position :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    target_position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_target_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    target_position_ := target_position_
    args := []__bindgen_gde.TypePtr {
        &target_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_target_position :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_target_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_navigation_layers :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    navigation_layers_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_navigation_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    navigation_layers_ := navigation_layers_
    args := []__bindgen_gde.TypePtr {
        &navigation_layers_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_navigation_layers :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_metadata_flags :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    flags_: Navigation_Path_Query_Parameters2d_Path_Metadata_Flags,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_metadata_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 24274129)
    }
    self := self
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_metadata_flags :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Navigation_Path_Query_Parameters2d_Path_Metadata_Flags) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_metadata_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 488152976)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_simplify_path :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_simplify_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_simplify_path :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_simplify_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_simplify_epsilon :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    epsilon_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_simplify_epsilon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    epsilon_ := epsilon_
    args := []__bindgen_gde.TypePtr {
        &epsilon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_simplify_epsilon :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_simplify_epsilon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_included_regions :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    regions_: Typed_Array(Rid),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_included_regions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    regions_ := regions_
    args := []__bindgen_gde.TypePtr {
        &regions_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_included_regions :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Typed_Array(Rid)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_included_regions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_excluded_regions :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    regions_: Typed_Array(Rid),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_excluded_regions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    regions_ := regions_
    args := []__bindgen_gde.TypePtr {
        &regions_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_excluded_regions :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: Typed_Array(Rid)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_excluded_regions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_path_return_max_length :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    length_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_return_max_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_path_return_max_length :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_return_max_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_path_return_max_radius :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_return_max_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_path_return_max_radius :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_return_max_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_path_search_max_polygons :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    max_polygons_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_search_max_polygons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    max_polygons_ := max_polygons_
    args := []__bindgen_gde.TypePtr {
        &max_polygons_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_path_search_max_polygons :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_search_max_polygons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_parameters2d_set_path_search_max_distance :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_search_max_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_parameters2d_get_path_search_max_distance :: proc "contextless" (
    self: Navigation_Path_Query_Parameters2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_search_max_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
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
navigation_path_query_parameters2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NavigationPathQueryParameters2D", true)
}

@(private = "file")
__class_name: String_Name