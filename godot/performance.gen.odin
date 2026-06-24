package godot

import __bindgen_gde "godot:gdext"

Performance_Constants :: enum {
}
Performance_Monitor :: enum int {
    Time_Fps = 0,
    Time_Process = 1,
    Time_Physics_Process = 2,
    Time_Navigation_Process = 3,
    Memory_Static = 4,
    Memory_Static_Max = 5,
    Memory_Message_Buffer_Max = 6,
    Object_Count = 7,
    Object_Resource_Count = 8,
    Object_Node_Count = 9,
    Object_Orphan_Node_Count = 10,
    Render_Total_Objects_In_Frame = 11,
    Render_Total_Primitives_In_Frame = 12,
    Render_Total_Draw_Calls_In_Frame = 13,
    Render_Video_Mem_Used = 14,
    Render_Texture_Mem_Used = 15,
    Render_Buffer_Mem_Used = 16,
    Physics_2d_Active_Objects = 17,
    Physics_2d_Collision_Pairs = 18,
    Physics_2d_Island_Count = 19,
    Physics_3d_Active_Objects = 20,
    Physics_3d_Collision_Pairs = 21,
    Physics_3d_Island_Count = 22,
    Audio_Output_Latency = 23,
    Navigation_Active_Maps = 24,
    Navigation_Region_Count = 25,
    Navigation_Agent_Count = 26,
    Navigation_Link_Count = 27,
    Navigation_Polygon_Count = 28,
    Navigation_Edge_Count = 29,
    Navigation_Edge_Merge_Count = 30,
    Navigation_Edge_Connection_Count = 31,
    Navigation_Edge_Free_Count = 32,
    Navigation_Obstacle_Count = 33,
    Pipeline_Compilations_Canvas = 34,
    Pipeline_Compilations_Mesh = 35,
    Pipeline_Compilations_Surface = 36,
    Pipeline_Compilations_Draw = 37,
    Pipeline_Compilations_Specialization = 38,
    Navigation_2d_Active_Maps = 39,
    Navigation_2d_Region_Count = 40,
    Navigation_2d_Agent_Count = 41,
    Navigation_2d_Link_Count = 42,
    Navigation_2d_Polygon_Count = 43,
    Navigation_2d_Edge_Count = 44,
    Navigation_2d_Edge_Merge_Count = 45,
    Navigation_2d_Edge_Connection_Count = 46,
    Navigation_2d_Edge_Free_Count = 47,
    Navigation_2d_Obstacle_Count = 48,
    Navigation_3d_Active_Maps = 49,
    Navigation_3d_Region_Count = 50,
    Navigation_3d_Agent_Count = 51,
    Navigation_3d_Link_Count = 52,
    Navigation_3d_Polygon_Count = 53,
    Navigation_3d_Edge_Count = 54,
    Navigation_3d_Edge_Merge_Count = 55,
    Navigation_3d_Edge_Connection_Count = 56,
    Navigation_3d_Edge_Free_Count = 57,
    Navigation_3d_Obstacle_Count = 58,
    Monitor_Max = 59,
}
Performance_Monitor_Type :: enum int {
    Monitor_Type_Quantity = 0,
    Monitor_Type_Memory = 1,
    Monitor_Type_Time = 2,
    Monitor_Type_Percentage = 3,
}



performance_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

performance_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_performance :: proc "contextless" () -> Performance {
    return __bindgen_gde.classdb_construct_object(performance_name_ref())
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

performance_get_monitor :: proc "contextless" (
    self: Performance,
    monitor_: Performance_Monitor,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_monitor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1943275655)
    }
    self := self
    monitor_ := monitor_
    args := []__bindgen_gde.TypePtr {
        &monitor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

performance_add_custom_monitor :: proc "contextless" (
    self: Performance,
    id_: String_Name,
    callable_: Callable,
    arguments_: Array,
    type_: Performance_Monitor_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_custom_monitor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3655788610)
    }
    self := self
    id_ := id_
    callable_ := callable_
    arguments_ := arguments_
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &callable_,
        &arguments_,
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

performance_remove_custom_monitor :: proc "contextless" (
    self: Performance,
    id_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_custom_monitor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

performance_has_custom_monitor :: proc "contextless" (
    self: Performance,
    id_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_custom_monitor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2041966384)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

performance_get_custom_monitor :: proc "contextless" (
    self: Performance,
    id_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_monitor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2138907829)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

performance_get_monitor_modification_time :: proc "contextless" (
    self: Performance,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_monitor_modification_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

performance_get_custom_monitor_names :: proc "contextless" (
    self: Performance,
) -> (ret: Typed_Array(String_Name)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_monitor_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

performance_get_custom_monitor_types :: proc "contextless" (
    self: Performance,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_monitor_types", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 969006518)
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
performance_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Performance", true)
}

@(private = "file")
__class_name: String_Name