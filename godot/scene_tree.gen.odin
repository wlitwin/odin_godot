package godot

import __bindgen_gde "godot:gdext"

Scene_Tree_Constants :: enum {
}
Scene_Tree_Group_Call_Flags :: enum int {
    Group_Call_Default = 0,
    Group_Call_Reverse = 1,
    Group_Call_Deferred = 2,
    Group_Call_Unique = 4,
}



scene_tree_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

scene_tree_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_scene_tree :: proc "contextless" () -> Scene_Tree {
    return cast(Scene_Tree)__bindgen_gde.classdb_construct_object(scene_tree_name_ref())
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

scene_tree_get_root :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Window) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1757182445)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_has_group :: proc "contextless" (
    self: Scene_Tree,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_is_accessibility_enabled :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_accessibility_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_is_accessibility_supported :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_accessibility_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_is_auto_accept_quit :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_auto_accept_quit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_auto_accept_quit :: proc "contextless" (
    self: Scene_Tree,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_accept_quit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_is_quit_on_go_back :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_quit_on_go_back", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_quit_on_go_back :: proc "contextless" (
    self: Scene_Tree,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_quit_on_go_back", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_set_debug_collisions_hint :: proc "contextless" (
    self: Scene_Tree,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_debug_collisions_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_is_debugging_collisions_hint :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_debugging_collisions_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_debug_paths_hint :: proc "contextless" (
    self: Scene_Tree,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_debug_paths_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_is_debugging_paths_hint :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_debugging_paths_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_debug_navigation_hint :: proc "contextless" (
    self: Scene_Tree,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_debug_navigation_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_is_debugging_navigation_hint :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_debugging_navigation_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_edited_scene_root :: proc "contextless" (
    self: Scene_Tree,
    scene_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_edited_scene_root", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    scene_ := scene_
    args := []__bindgen_gde.TypePtr {
        &scene_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_get_edited_scene_root :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_edited_scene_root", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3160264692)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_pause :: proc "contextless" (
    self: Scene_Tree,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pause", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_is_paused :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_paused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_create_timer :: proc "contextless" (
    self: Scene_Tree,
    time_sec_: f64,
    process_always_: Bool,
    process_in_physics_: Bool,
    ignore_time_scale_: Bool,
) -> (ret: Scene_Tree_Timer) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_timer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2709170273)
    }
    self := self
    time_sec_ := time_sec_
    process_always_ := process_always_
    process_in_physics_ := process_in_physics_
    ignore_time_scale_ := ignore_time_scale_
    args := []__bindgen_gde.TypePtr {
        &time_sec_,
        &process_always_,
        &process_in_physics_,
        &ignore_time_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_create_tween :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Tween) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_tween", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3426978995)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_get_processed_tweens :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Typed_Array(Tween)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_processed_tweens", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_get_node_count :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_get_frame :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_quit :: proc "contextless" (
    self: Scene_Tree,
    exit_code_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("quit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    exit_code_ := exit_code_
    args := []__bindgen_gde.TypePtr {
        &exit_code_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_set_physics_interpolation_enabled :: proc "contextless" (
    self: Scene_Tree,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_interpolation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_is_physics_interpolation_enabled :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_physics_interpolation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_queue_delete :: proc "contextless" (
    self: Scene_Tree,
    obj_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("queue_delete", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    obj_ := obj_
    args := []__bindgen_gde.TypePtr {
        &obj_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_call_group_flags :: proc "contextless" (
    self: Scene_Tree,
    flags_: Int,
    group_: String_Name,
    method_: String_Name,
    extra: ..Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("call_group_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1527739229)
    }
    self := self
    flags_ := flags_
    __fv_flags := variant_from(&flags_)
    group_ := group_
    __fv_group := variant_from(&group_)
    method_ := method_
    __fv_method := variant_from(&method_)
    __argv: [64]__bindgen_gde.VariantPtr
    __n := 0
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_flags
    __n += 1
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_group
    __n += 1
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_method
    __n += 1
    for __i in 0 ..< len(extra) {
        if __n >= 64 do break
        __argv[__n] = cast(__bindgen_gde.VariantPtr)&extra[__i]
        __n += 1
    }
    __ret: Variant
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(__bindgen_gde.VariantPtr)&__ret, nil)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__ret)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_flags)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_group)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_method)
    return
}

scene_tree_notify_group_flags :: proc "contextless" (
    self: Scene_Tree,
    call_flags_: Int,
    group_: String_Name,
    notification_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("notify_group_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1245489420)
    }
    self := self
    call_flags_ := call_flags_
    group_ := group_
    notification_ := notification_
    args := []__bindgen_gde.TypePtr {
        &call_flags_,
        &group_,
        &notification_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_set_group_flags :: proc "contextless" (
    self: Scene_Tree,
    call_flags_: Int,
    group_: String_Name,
    property_: String,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_group_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3497599527)
    }
    self := self
    call_flags_ := call_flags_
    group_ := group_
    property_ := property_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &call_flags_,
        &group_,
        &property_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_call_group :: proc "contextless" (
    self: Scene_Tree,
    group_: String_Name,
    method_: String_Name,
    extra: ..Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("call_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1257962832)
    }
    self := self
    group_ := group_
    __fv_group := variant_from(&group_)
    method_ := method_
    __fv_method := variant_from(&method_)
    __argv: [64]__bindgen_gde.VariantPtr
    __n := 0
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_group
    __n += 1
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_method
    __n += 1
    for __i in 0 ..< len(extra) {
        if __n >= 64 do break
        __argv[__n] = cast(__bindgen_gde.VariantPtr)&extra[__i]
        __n += 1
    }
    __ret: Variant
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(__bindgen_gde.VariantPtr)&__ret, nil)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__ret)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_group)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_method)
    return
}

scene_tree_notify_group :: proc "contextless" (
    self: Scene_Tree,
    group_: String_Name,
    notification_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("notify_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2415702435)
    }
    self := self
    group_ := group_
    notification_ := notification_
    args := []__bindgen_gde.TypePtr {
        &group_,
        &notification_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_set_group :: proc "contextless" (
    self: Scene_Tree,
    group_: String_Name,
    property_: String,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1279312029)
    }
    self := self
    group_ := group_
    property_ := property_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &group_,
        &property_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_get_nodes_in_group :: proc "contextless" (
    self: Scene_Tree,
    group_: String_Name,
) -> (ret: Typed_Array(Node)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_nodes_in_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 689397652)
    }
    self := self
    group_ := group_
    args := []__bindgen_gde.TypePtr {
        &group_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_get_first_node_in_group :: proc "contextless" (
    self: Scene_Tree,
    group_: String_Name,
) -> (ret: Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_first_node_in_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4071044623)
    }
    self := self
    group_ := group_
    args := []__bindgen_gde.TypePtr {
        &group_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_get_node_count_in_group :: proc "contextless" (
    self: Scene_Tree,
    group_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_count_in_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2458036349)
    }
    self := self
    group_ := group_
    args := []__bindgen_gde.TypePtr {
        &group_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_current_scene :: proc "contextless" (
    self: Scene_Tree,
    child_node_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    child_node_ := child_node_
    args := []__bindgen_gde.TypePtr {
        &child_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_get_current_scene :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3160264692)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_change_scene_to_file :: proc "contextless" (
    self: Scene_Tree,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("change_scene_to_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166001499)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_change_scene_to_packed :: proc "contextless" (
    self: Scene_Tree,
    packed_scene_: Packed_Scene,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("change_scene_to_packed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 107349098)
    }
    self := self
    packed_scene_ := packed_scene_
    args := []__bindgen_gde.TypePtr {
        &packed_scene_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_change_scene_to_node :: proc "contextless" (
    self: Scene_Tree,
    node_: Node,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("change_scene_to_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2584678054)
    }
    self := self
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_reload_current_scene :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reload_current_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_unload_current_scene :: proc "contextless" (
    self: Scene_Tree,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unload_current_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_set_multiplayer :: proc "contextless" (
    self: Scene_Tree,
    multiplayer_: Multiplayer_Api,
    root_path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_multiplayer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2385607013)
    }
    self := self
    multiplayer_ := multiplayer_
    root_path_ := root_path_
    args := []__bindgen_gde.TypePtr {
        &multiplayer_,
        &root_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_get_multiplayer :: proc "contextless" (
    self: Scene_Tree,
    for_path_: Node_Path,
) -> (ret: Multiplayer_Api) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_multiplayer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3453401404)
    }
    self := self
    for_path_ := for_path_
    args := []__bindgen_gde.TypePtr {
        &for_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_tree_set_multiplayer_poll_enabled :: proc "contextless" (
    self: Scene_Tree,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_multiplayer_poll_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_tree_is_multiplayer_poll_enabled :: proc "contextless" (
    self: Scene_Tree,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_multiplayer_poll_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
scene_tree_get_auto_accept_quit :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_auto_accept_quit(self)
}
scene_tree_get_quit_on_go_back :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_quit_on_go_back(self)
}
scene_tree_get_debug_collisions_hint :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_debugging_collisions_hint(self)
}
scene_tree_get_debug_paths_hint :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_debugging_paths_hint(self)
}
scene_tree_get_debug_navigation_hint :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_debugging_navigation_hint(self)
}
scene_tree_get_paused :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_paused(self)
}
scene_tree_set_paused :: proc "contextless" (self: Scene_Tree, value: Bool) {
    scene_tree_set_pause(self, value)
}
scene_tree_get_multiplayer_poll :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_multiplayer_poll_enabled(self)
}
scene_tree_set_multiplayer_poll :: proc "contextless" (self: Scene_Tree, value: Bool) {
    scene_tree_set_multiplayer_poll_enabled(self, value)
}
scene_tree_get_physics_interpolation :: proc "contextless" (self: Scene_Tree) -> Bool {
    return scene_tree_is_physics_interpolation_enabled(self)
}
scene_tree_set_physics_interpolation :: proc "contextless" (self: Scene_Tree, value: Bool) {
    scene_tree_set_physics_interpolation_enabled(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
scene_tree_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SceneTree", true)
}

@(private = "file")
__class_name: String_Name