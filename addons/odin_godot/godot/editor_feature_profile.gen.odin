package godot

import __bindgen_gde "godot:gdext"

Editor_Feature_Profile_Constants :: enum {
}
Editor_Feature_Profile_Feature :: enum int {
    Feature_3d = 0,
    Feature_Script = 1,
    Feature_Asset_Lib = 2,
    Feature_Scene_Tree = 3,
    Feature_Node_Dock = 4,
    Feature_Filesystem_Dock = 5,
    Feature_Import_Dock = 6,
    Feature_History_Dock = 7,
    Feature_Game = 8,
    Feature_Signals_Dock = 9,
    Feature_Groups_Dock = 10,
    Feature_Max = 11,
}



editor_feature_profile_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_feature_profile_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_feature_profile :: proc "contextless" () -> Editor_Feature_Profile {
    return cast(Editor_Feature_Profile)__bindgen_gde.classdb_construct_object(editor_feature_profile_name_ref())
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

editor_feature_profile_set_disable_class :: proc "contextless" (
    self: Editor_Feature_Profile,
    class_name_: String_Name,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_class", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2524380260)
    }
    self := self
    class_name_ := class_name_
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &class_name_,
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_feature_profile_is_class_disabled :: proc "contextless" (
    self: Editor_Feature_Profile,
    class_name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_class_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    class_name_ := class_name_
    args := []__bindgen_gde.TypePtr {
        &class_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_feature_profile_set_disable_class_editor :: proc "contextless" (
    self: Editor_Feature_Profile,
    class_name_: String_Name,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_class_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2524380260)
    }
    self := self
    class_name_ := class_name_
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &class_name_,
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_feature_profile_is_class_editor_disabled :: proc "contextless" (
    self: Editor_Feature_Profile,
    class_name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_class_editor_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    class_name_ := class_name_
    args := []__bindgen_gde.TypePtr {
        &class_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_feature_profile_set_disable_class_property :: proc "contextless" (
    self: Editor_Feature_Profile,
    class_name_: String_Name,
    property_: String_Name,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_class_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 865197084)
    }
    self := self
    class_name_ := class_name_
    property_ := property_
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &class_name_,
        &property_,
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_feature_profile_is_class_property_disabled :: proc "contextless" (
    self: Editor_Feature_Profile,
    class_name_: String_Name,
    property_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_class_property_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    class_name_ := class_name_
    property_ := property_
    args := []__bindgen_gde.TypePtr {
        &class_name_,
        &property_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_feature_profile_set_disable_feature :: proc "contextless" (
    self: Editor_Feature_Profile,
    feature_: Editor_Feature_Profile_Feature,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_feature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1884871044)
    }
    self := self
    feature_ := feature_
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &feature_,
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_feature_profile_is_feature_disabled :: proc "contextless" (
    self: Editor_Feature_Profile,
    feature_: Editor_Feature_Profile_Feature,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_feature_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2974403161)
    }
    self := self
    feature_ := feature_
    args := []__bindgen_gde.TypePtr {
        &feature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_feature_profile_get_feature_name :: proc "contextless" (
    self: Editor_Feature_Profile,
    feature_: Editor_Feature_Profile_Feature,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_feature_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3401335809)
    }
    self := self
    feature_ := feature_
    args := []__bindgen_gde.TypePtr {
        &feature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_feature_profile_save_to_file :: proc "contextless" (
    self: Editor_Feature_Profile,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_to_file", true)
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

editor_feature_profile_load_from_file :: proc "contextless" (
    self: Editor_Feature_Profile,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_from_file", true)
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_feature_profile_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorFeatureProfile", true)
}

@(private = "file")
__class_name: String_Name