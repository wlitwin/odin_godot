package godot

import __bindgen_gde "godot:gdext"

Editor_Export_Platform_Pc_Constants :: enum {
}



editor_export_platform_pc_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_export_platform_pc_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_export_platform_pc :: proc "contextless" () -> Editor_Export_Platform_Pc {
    return cast(Editor_Export_Platform_Pc)__bindgen_gde.classdb_construct_object(editor_export_platform_pc_name_ref())
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_export_platform_pc_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorExportPlatformPC", true)
}

@(private = "file")
__class_name: String_Name