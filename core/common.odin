package core

import "godot:gdext"
import "godot:godot"

import "core:strings"

// ----------------------------------------------------------------------------
// Virtual dispatch shared between OdinLanguage / OdinScript / OdinResourceFormatLoader.
//
// We use the `get_virtual_call_data_func` + `call_virtual_with_data_func` pair from
// ExtensionClassCreationInfo2. The "call data" we hand back from get_virtual_call_data
// IS the per-virtual call proc (an ExtensionClassCallVirtual), so the actual dispatch
// is a single cast-and-call with no per-call name lookup.
//
// Returning `nil` from get_virtual_call_data tells Godot the virtual is NOT overridden,
// so the engine falls back to the (safe) base-class default. That is how all the
// Phase-1 STUB virtuals are handled: we simply don't list them.
// ----------------------------------------------------------------------------

Virtual_Entry :: struct {
    name: string, // virtual method name, e.g. "_get_name" (static literal — never freed)
    fn:   gdext.ExtensionClassCallVirtual,
}

// Convert an engine-supplied StringName (by pointer) to an owned Odin string.
string_name_to_odin :: proc(name: gdext.StringNamePtr, allocator := context.allocator) -> string {
    sn := (cast(^godot.String_Name)name)^
    s := godot.new_string_string_name(sn)
    return string_to_odin(s, allocator)
}

// Match the engine-supplied virtual name against the table by string content.
// Only called when the engine resolves a class's virtuals (registration-time), so
// the per-call allocation is irrelevant. Requires a valid Odin context.
lookup_virtual :: proc(table: []Virtual_Entry, name: gdext.StringNamePtr) -> rawptr {
    incoming := string_name_to_odin(name)
    defer delete(incoming)
    for entry in table {
        if entry.name == incoming {
            return cast(rawptr)entry.fn
        }
    }
    return nil
}

// Shared `call_virtual_with_data_func`: the userdata is the call proc itself.
call_virtual_with_data :: proc "c" (
    instance: gdext.ExtensionClassInstancePtr,
    name: gdext.StringNamePtr,
    userdata: rawptr,
    args: [^]gdext.TypePtr,
    ret: gdext.TypePtr,
) {
    if userdata == nil {
        return
    }
    fn := cast(gdext.ExtensionClassCallVirtual)userdata
    fn(instance, args, ret)
}

// ----------------------------------------------------------------------------
// ptrcall return writers. Each engine virtual hands us a `ret` TypePtr pointing at
// pre-allocated storage of the return type; we write the value through it.
// ----------------------------------------------------------------------------

ret_bool :: proc "contextless" (ret: gdext.TypePtr, v: bool) {
    (cast(^bool)ret)^ = v
}

ret_int :: proc "contextless" (ret: gdext.TypePtr, v: i64) {
    (cast(^i64)ret)^ = v
}

ret_string :: proc "contextless" (ret: gdext.TypePtr, v: godot.String) {
    (cast(^godot.String)ret)^ = v
}

ret_string_name :: proc "contextless" (ret: gdext.TypePtr, v: godot.String_Name) {
    (cast(^godot.String_Name)ret)^ = v
}

ret_object :: proc "contextless" (ret: gdext.TypePtr, v: gdext.ObjectPtr) {
    (cast(^gdext.ObjectPtr)ret)^ = v
}

ret_psa :: proc "contextless" (ret: gdext.TypePtr, v: godot.Packed_String_Array) {
    (cast(^godot.Packed_String_Array)ret)^ = v
}

ret_variant :: proc "contextless" (ret: gdext.TypePtr, v: godot.Variant) {
    (cast(^godot.Variant)ret)^ = v
}

// Build a fresh Packed_String_Array from a set of latin1/utf8 literals. The caller
// (engine) takes ownership of the returned array, so a new one is built every call.
//
// NOTE: we resolve the `push_back` builtin method ourselves rather than using the
// generated `godot.packed_string_array_*` wrapper — that wrapper passes the wrong
// interned name ("packed_string_array_push_back" instead of "push_back") to
// variant_get_ptr_builtin_method, yielding a null bind that crashes on call.
@(private = "file")
psa_push_back: gdext.PtrBuiltInMethod

make_psa :: proc "contextless" (items: ..cstring) -> godot.Packed_String_Array {
    if psa_push_back == nil {
        name := godot.new_string_name_cstring("push_back", true)
        psa_push_back = gdext.variant_get_ptr_builtin_method(.Packed_String_Array, &name, HASH_PSA_PUSH_BACK)
    }
    psa := godot.new_packed_string_array()
    for item in items {
        s := godot.new_string_cstring(item)
        arg0 := cast(gdext.TypePtr)&s
        result: bool // push_back returns bool; the ptrcall writes through here
        psa_push_back(cast(gdext.TypePtr)&psa, &arg0, cast(gdext.TypePtr)&result, 1)
    }
    return psa
}

// Convert a Godot String to an owned Odin string using the current context allocator.
string_to_odin :: proc(s: godot.String, allocator := context.allocator) -> string {
    s := s
    length := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
    if length <= 0 {
        return ""
    }
    buf := make([]u8, length, allocator)
    gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), length)
    return string(buf)
}

// ----------------------------------------------------------------------------
// Manually-resolved Godot method-bind hashes.
//
// These are the `hash` values from Godot's extension_api.json for binds the core resolves
// by hand (rather than through the generated wrappers). They are pinned to the tested
// engine (Godot 4.6): re-derive each from extension_api.json on a Godot version bump —
// look up the class/builtin's method entry and copy its "hash". A wrong hash yields a
// nil bind that crashes on first call.
// (core/instance.odin carries two more, resolved at its own call sites: 2240911060 for
// RefCounted::reference/unreference and 2586408642 for Node::set_process /
// set_physics_process.)
// ----------------------------------------------------------------------------

// Packed_String_Array builtin `push_back` (variant_get_ptr_builtin_method).
HASH_PSA_PUSH_BACK :: 816187996

// ----------------------------------------------------------------------------
// Shell quoting. Every path/setting interpolated into a `libc.system` command line
// MUST pass through this: paths can carry apostrophes (breaking naive '%s' splicing)
// and project settings are user-editable text (shell injection otherwise).
//
// CANONICAL copy — core/diag and core/complete keep small private mirrors (they are
// headless-testable packages that must not import core). Keep the three in sync.
// ----------------------------------------------------------------------------

// Quote `s` for a POSIX shell: wrap in single quotes, escaping embedded ' as '\''.
shell_quote :: proc(s: string, allocator := context.allocator) -> string {
    b := strings.builder_make(allocator)
    strings.write_byte(&b, '\'')
    for i in 0 ..< len(s) {
        if s[i] == '\'' {
            strings.write_string(&b, `'\''`)
        } else {
            strings.write_byte(&b, s[i])
        }
    }
    strings.write_byte(&b, '\'')
    return strings.to_string(b)
}

