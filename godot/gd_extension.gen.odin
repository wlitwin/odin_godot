package godot

import __bindgen_gde "godot:gdext"

Gd_Extension_Constants :: enum {
}
Gd_Extension_Initialization_Level :: enum int {
    Initialization_Level_Core = 0,
    Initialization_Level_Servers = 1,
    Initialization_Level_Scene = 2,
    Initialization_Level_Editor = 3,
}



gd_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gd_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gd_extension :: proc "contextless" () -> Gd_Extension {
    return cast(Gd_Extension)__bindgen_gde.classdb_construct_object(gd_extension_name_ref())
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

gd_extension_is_library_open :: proc "contextless" (
    self: Gd_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_library_open", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gd_extension_get_minimum_library_initialization_level :: proc "contextless" (
    self: Gd_Extension,
) -> (ret: Gd_Extension_Initialization_Level) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimum_library_initialization_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 964858755)
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
gd_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GDExtension", true)
}

@(private = "file")
__class_name: String_Name