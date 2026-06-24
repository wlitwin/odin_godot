package godot

import __bindgen_gde "godot:gdext"

Editor_Toaster_Constants :: enum {
}
Editor_Toaster_Severity :: enum int {
    Severity_Info = 0,
    Severity_Warning = 1,
    Severity_Error = 2,
}



editor_toaster_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_toaster_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_toaster :: proc "contextless" () -> Editor_Toaster {
    return __bindgen_gde.classdb_construct_object(editor_toaster_name_ref())
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

editor_toaster_push_toast :: proc "contextless" (
    self: Editor_Toaster,
    message_: String,
    severity_: Editor_Toaster_Severity,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_toast", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1813923476)
    }
    self := self
    message_ := message_
    severity_ := severity_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &message_,
        &severity_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_toaster_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorToaster", true)
}

@(private = "file")
__class_name: String_Name