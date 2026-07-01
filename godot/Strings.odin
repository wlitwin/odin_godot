package godot

import gd "godot:gdext" 
import "core:mem"

@(private)
EmptyString := String{}

@(private)
EmptyStringName := String_Name{}

string_empty :: proc "contextless" () -> String {
    return EmptyString
}

string_name_empty :: proc "contextless" () -> String_Name {
    return EmptyStringName
}

string_empty_ref :: proc "contextless" () -> ^String {
    return &EmptyString
}

string_name_empty_ref :: proc "contextless" () -> ^String_Name {
    return &EmptyStringName
}

/*
Clones a UTF8 Odin string into a Godot String

Inputs:
- from: The string to be cloned

Returns:
- res: A cloned Godot String
*/
new_string_odin :: proc "contextless" (from: string) -> (ret: String) {
    ret = String{}

    // N.B. we're transmuting the odin string into a cstring regardless of if it has a terminating null
    // byte or not. `string_new_with_utf8_chars_and_len2` takes a length, so we don't depend on the
    // terminating null byte.
    as_cstring := cast(cstring)(transmute(mem.Raw_String)from).data
    gd.string_new_with_utf8_chars_and_len2(&ret, as_cstring, cast(i64)len(from))
    return
}

/*
Clones a UTF8 cstring into a Godot String

Inputs:
- from: The cstring to be cloned. Must be null-terminated.

Returns:
- res: A cloned Godot String
*/
new_string_cstring :: proc "contextless" (from: cstring) -> (ret: String) {
    ret = String{}
    gd.string_new_with_utf8_chars(&ret, from)
    return
}

/*
Clones a UTF8 Odin string into a Godot String_Name

Inputs:
- from: The string to be cloned

Returns:
- res: A cloned Godot String_Name
*/
new_string_name_odin :: proc "contextless" (from: string) -> (ret: String_Name) {
    ret = String_Name{}

    // N.B. we're transmuting the odin string into a cstring regardless of if it has a terminating null
    // byte or not. `string_new_with_utf8_chars_and_len2` takes a length, so we don't depend on the
    // terminating null byte.
    as_cstring := cast(cstring)(transmute(mem.Raw_String)from).data
    gd.string_name_new_with_utf8_chars_and_len(&ret, as_cstring, cast(i64)len(from))
    return
}

/*
Clones a UTF8 cstring into a Godot String_Name

Inputs:
- from: The cstring to be cloned. Must be null-terminated.

Returns:
- res: A cloned Godot String_Name
*/
new_string_name_cstring :: proc "contextless" (from: cstring, static: bool) -> (ret: String_Name) {
    ret = String_Name{}
    if static {
        // `static = true` promises a permanent (interned-for-the-program) name — method / signal /
        // action / class-name literals. Use Godot's static StringName constructor (the only one
        // that takes the flag), which tracks the atom as static rather than refcounted: it isn't
        // reported as a leak at shutdown and skips the per-construction refcount churn. Static
        // names are ASCII identifiers, so latin1 is the right (and only static-capable) path — the
        // same constructor the core uses for its own class names. Previously the flag was ignored
        // and every name went through the refcounted utf8 path, "leaking" a refcount per call.
        gd.string_name_new_with_latin1_chars(&ret, from, true)
    } else {
        // Transient and/or non-ASCII name — refcounted utf8 StringName.
        gd.string_name_new_with_utf8_chars(&ret, from)
    }
    return
}


new_node_path_cstring :: proc "contextless" (from: cstring) -> Node_Path {
    str: String
    gd.string_new_with_utf8_chars(&str, from)
    return new_node_path_string(str)
}
