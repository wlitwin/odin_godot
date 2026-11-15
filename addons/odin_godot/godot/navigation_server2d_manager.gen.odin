package godot

import __bindgen_gde "godot:gdext"

Navigation_Server2d_Manager_Constants :: enum {
}



navigation_server2d_manager_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

navigation_server2d_manager_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_navigation_server2d_manager :: proc "contextless" () -> Navigation_Server2d_Manager {
    return cast(Navigation_Server2d_Manager)__bindgen_gde.classdb_construct_object(navigation_server2d_manager_name_ref())
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

navigation_server2d_manager_register_server :: proc "contextless" (
    self: Navigation_Server2d_Manager,
    name_: String,
    create_callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_server", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2137474292)
    }
    self := self
    name_ := name_
    create_callback_ := create_callback_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &create_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_server2d_manager_set_default_server :: proc "contextless" (
    self: Navigation_Server2d_Manager,
    name_: String,
    priority_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_server", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2956805083)
    }
    self := self
    name_ := name_
    priority_ := priority_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
navigation_server2d_manager_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NavigationServer2DManager", true)
}

@(private = "file")
__class_name: String_Name