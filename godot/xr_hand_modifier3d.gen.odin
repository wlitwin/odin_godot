package godot

import __bindgen_gde "godot:gdext"

Xr_Hand_Modifier3d_Constants :: enum {
}
Xr_Hand_Modifier3d_Bone_Update :: enum int {
    Bone_Update_Full = 0,
    Bone_Update_Rotation_Only = 1,
    Bone_Update_Max = 2,
}



xr_hand_modifier3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_hand_modifier3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_hand_modifier3d :: proc "contextless" () -> Xr_Hand_Modifier3d {
    return cast(Xr_Hand_Modifier3d)__bindgen_gde.classdb_construct_object(xr_hand_modifier3d_name_ref())
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

xr_hand_modifier3d_set_hand_tracker :: proc "contextless" (
    self: Xr_Hand_Modifier3d,
    tracker_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_tracker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    tracker_name_ := tracker_name_
    args := []__bindgen_gde.TypePtr {
        &tracker_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_modifier3d_get_hand_tracker :: proc "contextless" (
    self: Xr_Hand_Modifier3d,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_tracker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_hand_modifier3d_set_bone_update :: proc "contextless" (
    self: Xr_Hand_Modifier3d,
    bone_update_: Xr_Hand_Modifier3d_Bone_Update,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bone_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635701455)
    }
    self := self
    bone_update_ := bone_update_
    args := []__bindgen_gde.TypePtr {
        &bone_update_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_modifier3d_get_bone_update :: proc "contextless" (
    self: Xr_Hand_Modifier3d,
) -> (ret: Xr_Hand_Modifier3d_Bone_Update) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2873665691)
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
xr_hand_modifier3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRHandModifier3D", true)
}

@(private = "file")
__class_name: String_Name