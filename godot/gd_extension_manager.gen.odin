package godot

import __bindgen_gde "godot:gdext"

Gd_Extension_Manager_Constants :: enum {
}
Gd_Extension_Manager_Load_Status :: enum int {
    Load_Status_Ok = 0,
    Load_Status_Failed = 1,
    Load_Status_Already_Loaded = 2,
    Load_Status_Not_Loaded = 3,
    Load_Status_Needs_Restart = 4,
}



gd_extension_manager_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gd_extension_manager_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gd_extension_manager :: proc "contextless" () -> Gd_Extension_Manager {
    return cast(Gd_Extension_Manager)__bindgen_gde.classdb_construct_object(gd_extension_manager_name_ref())
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

gd_extension_manager_load_extension :: proc "contextless" (
    self: Gd_Extension_Manager,
    path_: String,
) -> (ret: Gd_Extension_Manager_Load_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4024158731)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_extension_manager_load_extension_from_function :: proc "contextless" (
    self: Gd_Extension_Manager,
    path_: String,
    init_func_: ^rawptr,
) -> (ret: Gd_Extension_Manager_Load_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_extension_from_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1565094761)
    }
    self := self
    path_ := path_
    init_func_ := init_func_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &init_func_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_extension_manager_reload_extension :: proc "contextless" (
    self: Gd_Extension_Manager,
    path_: String,
) -> (ret: Gd_Extension_Manager_Load_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reload_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4024158731)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_extension_manager_unload_extension :: proc "contextless" (
    self: Gd_Extension_Manager,
    path_: String,
) -> (ret: Gd_Extension_Manager_Load_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unload_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4024158731)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_extension_manager_is_extension_loaded :: proc "contextless" (
    self: Gd_Extension_Manager,
    path_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_extension_loaded", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_extension_manager_get_loaded_extensions :: proc "contextless" (
    self: Gd_Extension_Manager,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_loaded_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_extension_manager_get_extension :: proc "contextless" (
    self: Gd_Extension_Manager,
    path_: String,
) -> (ret: Gd_Extension) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 49743343)
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
gd_extension_manager_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GDExtensionManager", true)
}

@(private = "file")
__class_name: String_Name