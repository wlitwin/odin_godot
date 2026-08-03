package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Render_Model_Manager_Constants :: enum {
}
Open_Xr_Render_Model_Manager_Render_Model_Tracker :: enum int {
    Render_Model_Tracker_Any = 0,
    Render_Model_Tracker_None_Set = 1,
    Render_Model_Tracker_Left_Hand = 2,
    Render_Model_Tracker_Right_Hand = 3,
}



open_xr_render_model_manager_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_render_model_manager_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_render_model_manager :: proc "contextless" () -> Open_Xr_Render_Model_Manager {
    return cast(Open_Xr_Render_Model_Manager)__bindgen_gde.classdb_construct_object(open_xr_render_model_manager_name_ref())
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

open_xr_render_model_manager_get_tracker :: proc "contextless" (
    self: Open_Xr_Render_Model_Manager,
) -> (ret: Open_Xr_Render_Model_Manager_Render_Model_Tracker) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2456466356)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_manager_set_tracker :: proc "contextless" (
    self: Open_Xr_Render_Model_Manager,
    tracker_: Open_Xr_Render_Model_Manager_Render_Model_Tracker,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tracker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2814627380)
    }
    self := self
    tracker_ := tracker_
    args := []__bindgen_gde.TypePtr {
        &tracker_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_render_model_manager_get_make_local_to_pose :: proc "contextless" (
    self: Open_Xr_Render_Model_Manager,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_make_local_to_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_manager_set_make_local_to_pose :: proc "contextless" (
    self: Open_Xr_Render_Model_Manager,
    make_local_to_pose_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_make_local_to_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    make_local_to_pose_ := make_local_to_pose_
    args := []__bindgen_gde.TypePtr {
        &make_local_to_pose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_render_model_manager_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRRenderModelManager", true)
}

@(private = "file")
__class_name: String_Name