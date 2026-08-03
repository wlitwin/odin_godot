package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Render_Model_Extension_Constants :: enum {
}



open_xr_render_model_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_render_model_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_render_model_extension :: proc "contextless" () -> Open_Xr_Render_Model_Extension {
    return cast(Open_Xr_Render_Model_Extension)__bindgen_gde.classdb_construct_object(open_xr_render_model_extension_name_ref())
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

open_xr_render_model_extension_is_active :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_create :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_id_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 937000113)
    }
    self := self
    render_model_id_ := render_model_id_
    args := []__bindgen_gde.TypePtr {
        &render_model_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_destroy :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_destroy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    render_model_ := render_model_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_render_model_extension_render_model_get_all :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
) -> (ret: Typed_Array(Rid)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_new_scene_instance :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
) -> (ret: Node3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_new_scene_instance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 788010739)
    }
    self := self
    render_model_ := render_model_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_get_subaction_paths :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_subaction_paths", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2801473409)
    }
    self := self
    render_model_ := render_model_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_get_top_level_path :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_top_level_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 642473191)
    }
    self := self
    render_model_ := render_model_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_get_confidence :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
) -> (ret: Xr_Pose_Tracking_Confidence) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_confidence", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2350330949)
    }
    self := self
    render_model_ := render_model_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_get_root_transform :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_root_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1128465797)
    }
    self := self
    render_model_ := render_model_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_get_animatable_node_count :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_animatable_node_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    render_model_ := render_model_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_get_animatable_node_name :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_animatable_node_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1464764419)
    }
    self := self
    render_model_ := render_model_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_is_animatable_node_visible :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_is_animatable_node_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3120086654)
    }
    self := self
    render_model_ := render_model_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_render_model_extension_render_model_get_animatable_node_transform :: proc "contextless" (
    self: Open_Xr_Render_Model_Extension,
    render_model_: Rid,
    index_: Int,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_model_get_animatable_node_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1050775521)
    }
    self := self
    render_model_ := render_model_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &render_model_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_render_model_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRRenderModelExtension", true)
}

@(private = "file")
__class_name: String_Name