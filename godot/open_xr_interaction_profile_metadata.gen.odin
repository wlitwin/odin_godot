package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Interaction_Profile_Metadata_Constants :: enum {
}



open_xr_interaction_profile_metadata_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_interaction_profile_metadata_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_interaction_profile_metadata :: proc "contextless" () -> Open_Xr_Interaction_Profile_Metadata {
    return cast(Open_Xr_Interaction_Profile_Metadata)__bindgen_gde.classdb_construct_object(open_xr_interaction_profile_metadata_name_ref())
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

open_xr_interaction_profile_metadata_register_profile_rename :: proc "contextless" (
    self: Open_Xr_Interaction_Profile_Metadata,
    old_name_: String,
    new_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_profile_rename", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3186203200)
    }
    self := self
    old_name_ := old_name_
    new_name_ := new_name_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &new_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interaction_profile_metadata_register_path_rename :: proc "contextless" (
    self: Open_Xr_Interaction_Profile_Metadata,
    old_name_: String,
    new_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_path_rename", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3186203200)
    }
    self := self
    old_name_ := old_name_
    new_name_ := new_name_
    args := []__bindgen_gde.TypePtr {
        &old_name_,
        &new_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interaction_profile_metadata_register_top_level_path :: proc "contextless" (
    self: Open_Xr_Interaction_Profile_Metadata,
    display_name_: String,
    openxr_path_: String,
    openxr_extension_names_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_top_level_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 254767734)
    }
    self := self
    display_name_ := display_name_
    openxr_path_ := openxr_path_
    openxr_extension_names_ := openxr_extension_names_
    args := []__bindgen_gde.TypePtr {
        &display_name_,
        &openxr_path_,
        &openxr_extension_names_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interaction_profile_metadata_register_interaction_profile :: proc "contextless" (
    self: Open_Xr_Interaction_Profile_Metadata,
    display_name_: String,
    openxr_path_: String,
    openxr_extension_names_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_interaction_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 254767734)
    }
    self := self
    display_name_ := display_name_
    openxr_path_ := openxr_path_
    openxr_extension_names_ := openxr_extension_names_
    args := []__bindgen_gde.TypePtr {
        &display_name_,
        &openxr_path_,
        &openxr_extension_names_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interaction_profile_metadata_register_io_path :: proc "contextless" (
    self: Open_Xr_Interaction_Profile_Metadata,
    interaction_profile_: String,
    display_name_: String,
    toplevel_path_: String,
    openxr_path_: String,
    openxr_extension_names_: String,
    action_type_: Open_Xr_Action_Action_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_io_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3443511926)
    }
    self := self
    interaction_profile_ := interaction_profile_
    display_name_ := display_name_
    toplevel_path_ := toplevel_path_
    openxr_path_ := openxr_path_
    openxr_extension_names_ := openxr_extension_names_
    action_type_ := action_type_
    args := []__bindgen_gde.TypePtr {
        &interaction_profile_,
        &display_name_,
        &toplevel_path_,
        &openxr_path_,
        &openxr_extension_names_,
        &action_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_interaction_profile_metadata_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRInteractionProfileMetadata", true)
}

@(private = "file")
__class_name: String_Name