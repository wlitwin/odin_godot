package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Action_Map_Constants :: enum {
}



open_xr_action_map_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_action_map_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_action_map :: proc "contextless" () -> Open_Xr_Action_Map {
    return cast(Open_Xr_Action_Map)__bindgen_gde.classdb_construct_object(open_xr_action_map_name_ref())
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

open_xr_action_map_set_action_sets :: proc "contextless" (
    self: Open_Xr_Action_Map,
    action_sets_: Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_action_sets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    action_sets_ := action_sets_
    args := []__bindgen_gde.TypePtr {
        &action_sets_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_action_map_get_action_sets :: proc "contextless" (
    self: Open_Xr_Action_Map,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_action_sets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_get_action_set_count :: proc "contextless" (
    self: Open_Xr_Action_Map,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_action_set_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_find_action_set :: proc "contextless" (
    self: Open_Xr_Action_Map,
    name_: String,
) -> (ret: Open_Xr_Action_Set) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_action_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1888809267)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_get_action_set :: proc "contextless" (
    self: Open_Xr_Action_Map,
    idx_: Int,
) -> (ret: Open_Xr_Action_Set) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_action_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1789580336)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_add_action_set :: proc "contextless" (
    self: Open_Xr_Action_Map,
    action_set_: Open_Xr_Action_Set,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_action_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2093310581)
    }
    self := self
    action_set_ := action_set_
    args := []__bindgen_gde.TypePtr {
        &action_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_action_map_remove_action_set :: proc "contextless" (
    self: Open_Xr_Action_Map,
    action_set_: Open_Xr_Action_Set,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_action_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2093310581)
    }
    self := self
    action_set_ := action_set_
    args := []__bindgen_gde.TypePtr {
        &action_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_action_map_set_interaction_profiles :: proc "contextless" (
    self: Open_Xr_Action_Map,
    interaction_profiles_: Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_interaction_profiles", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    interaction_profiles_ := interaction_profiles_
    args := []__bindgen_gde.TypePtr {
        &interaction_profiles_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_action_map_get_interaction_profiles :: proc "contextless" (
    self: Open_Xr_Action_Map,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interaction_profiles", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_get_interaction_profile_count :: proc "contextless" (
    self: Open_Xr_Action_Map,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interaction_profile_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_find_interaction_profile :: proc "contextless" (
    self: Open_Xr_Action_Map,
    name_: String,
) -> (ret: Open_Xr_Interaction_Profile) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_interaction_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3095875538)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_get_interaction_profile :: proc "contextless" (
    self: Open_Xr_Action_Map,
    idx_: Int,
) -> (ret: Open_Xr_Interaction_Profile) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interaction_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2546151210)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_action_map_add_interaction_profile :: proc "contextless" (
    self: Open_Xr_Action_Map,
    interaction_profile_: Open_Xr_Interaction_Profile,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_interaction_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2697953512)
    }
    self := self
    interaction_profile_ := interaction_profile_
    args := []__bindgen_gde.TypePtr {
        &interaction_profile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_action_map_remove_interaction_profile :: proc "contextless" (
    self: Open_Xr_Action_Map,
    interaction_profile_: Open_Xr_Interaction_Profile,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_interaction_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2697953512)
    }
    self := self
    interaction_profile_ := interaction_profile_
    args := []__bindgen_gde.TypePtr {
        &interaction_profile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_action_map_create_default_action_sets :: proc "contextless" (
    self: Open_Xr_Action_Map,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_default_action_sets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_action_map_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRActionMap", true)
}

@(private = "file")
__class_name: String_Name