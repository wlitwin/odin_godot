#+build wasm32, wasm64p32
package core

import "godot:gdext"
import "godot:godot"

// ----------------------------------------------------------------------------
// WEB stubs for the editor developer-experience features (real `_validate` and the syntax
// highlighter). The browser build has no Odin compiler, no editor, and no filesystem to
// shell out to, so these are safe no-ops mirroring the previous default behavior:
//   * `lv_validate` -> `{ }` empty Dictionary (treated as valid)
//   * `lv_frame`    -> nothing
// The real native implementations live in validate.odin / highlighter.odin.
// ----------------------------------------------------------------------------

lv_validate :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    (cast(^godot.Dictionary)ret)^ = godot.new_dictionary_default()
}

lv_frame :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
}

// No Odin compiler / ols / editor on web — `_complete_code` returns a well-formed
// `{ result: FAILED }` (the engine requires the "result" key). The real native
// implementation lives in complete.odin.
lv_complete_code :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    d := godot.new_dictionary_default()
    k := godot.new_string_cstring("result")
    kv := godot.variant_from_string(&k)
    code := godot.Int(1) // FAILED
    cv := godot.variant_from_int(&code)
    godot.dictionary_set(&d, kv, cv)
    (cast(^godot.Dictionary)ret)^ = d
}

// No persistent ols session on web — `_finish` is a no-op. The real native implementation
// (which kills the ols subprocess) lives in complete.odin.
lv_finish_session :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
}

// No filesystem saving on web (export-only, no editor) — the ResourceFormatSaver is desktop-only.
odin_saver_register :: proc() {
}
