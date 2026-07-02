#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"

import "base:runtime"

// ----------------------------------------------------------------------------
// OdinSyntaxHighlighter — an `EditorSyntaxHighlighter` that token-colors `.odin` scripts
// in the editor's Script panel.
//
// Registration mirrors the miniml C reference: the ScriptEditor UI does not exist at
// extension-init time, so we DEFER registration to the first editor `_frame` (the language
// virtual `lv_frame`), guarded by a one-time flag and an editor-hint check. We touch ONLY
// ScriptEditor (`ScriptEditor.register_syntax_highlighter`) — NEVER EditorHelp, whose
// doc-generation paths crash on extension classes.
//
// The highlighter implements four virtuals:
//   * `_get_name`                     -> "Odin"
//   * `_get_supported_languages`      -> ["Odin"]  (matched against OdinLanguage._get_name)
//   * `_create`                       -> a fresh instance (the editor clones one per editor)
//   * `_get_line_syntax_highlighting` -> { start_column(int): { "color": Color } }  (the
//     SyntaxHighlighter base virtual; the engine colors from each column until the next).
//
// Colors are sensible dark-theme constants (NOT pulled from EditorSettings — that is an
// easy later refinement). The tokenizer is byte-based, rune-column-accurate, and never
// crashes on malformed input — a bad line still returns a well-formed Dictionary.
//
// LIMITATION: block comments are highlighted per-line (an unterminated `/*` colors to
// end-of-line); a `/* ... */` opened on a previous line is not tracked across lines.
// ----------------------------------------------------------------------------

@(private = "file")
odin_highlighter_class_name: godot.String_Name

@(private = "file")
highlighter_virtuals: [dynamic]Virtual_Entry

@(private = "file")
odin_highlighter_object: gdext.ObjectPtr

OdinSyntaxHighlighter :: struct {
    object: gdext.ObjectPtr,
}

@(private = "file")
highlighter_binding_callbacks := gdext.InstanceBindingCallbacks {
    create    = nil,
    free      = nil,
    reference = nil,
}

// ---- token colors (dark-theme constants) ----
@(private = "file")
C_TEXT :: godot.Color{0.86, 0.86, 0.90, 1.0}
@(private = "file")
C_KEYWORD :: godot.Color{0.90, 0.55, 0.30, 1.0}
@(private = "file")
C_CONTROL :: godot.Color{1.00, 0.44, 0.52, 1.0}
@(private = "file")
C_COMMENT :: godot.Color{0.50, 0.50, 0.55, 1.0}
@(private = "file")
C_STRING :: godot.Color{0.90, 0.86, 0.45, 1.0}
@(private = "file")
C_NUMBER :: godot.Color{0.50, 0.80, 0.95, 1.0}
@(private = "file")
C_TYPE :: godot.Color{0.45, 0.85, 0.75, 1.0}
@(private = "file")
C_FUNC :: godot.Color{0.67, 0.79, 0.90, 1.0}

// Odin reserved words (mirrors OdinLanguage._get_reserved_words); control-flow words get
// a distinct color (mirrors lv_is_control_flow_keyword).
@(private = "file")
is_keyword :: proc(w: string) -> (kw: bool, control: bool) {
    switch w {
    case "if", "else", "for", "switch", "case", "when", "where", "break", "continue",
         "fallthrough", "return", "defer", "or_else", "or_return", "in", "not_in":
        return true, true
    case "package", "import", "proc", "struct", "enum", "union", "map", "bit_set",
         "using", "cast", "transmute", "auto_cast", "distinct", "context", "nil",
         "true", "false", "dynamic", "matrix":
        return true, false
    }
    return false, false
}

@(private = "file")
is_digit :: proc(b: u8) -> bool {return b >= '0' && b <= '9'}

@(private = "file")
is_alpha :: proc(b: u8) -> bool {
    return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || b == '_' || b >= 0x80
}

@(private = "file")
is_alnum :: proc(b: u8) -> bool {return is_alpha(b) || is_digit(b)}

// Add a `{ "color": color }` entry at rune-column `col`. Only emits when the color changes
// from the previous entry (`last`) — entries persist until the next, so contiguous same-
// color regions need just one entry.
@(private = "file")
hl_emit :: proc(d: ^godot.Dictionary, last: ^godot.Color, col: int, color: godot.Color) {
    if color == last^ {
        return
    }
    last^ = color
    ci := godot.Int(col)
    kv := godot.variant_from_int(&ci)
    inner := godot.new_dictionary_default()
    c := color
    cv := godot.variant_from_color(&c)
    ck := godot.new_string_cstring("color")
    ckv := godot.variant_from_string(&ck)
    godot.dictionary_set(&inner, ckv, cv)
    iv := godot.variant_from_dictionary(&inner)
    godot.dictionary_set(d, kv, iv)
}

// Tokenize one line of Odin into the highlight Dictionary. `s` is UTF-8; `out` is keyed by
// RUNE column (codepoint index), which is what Godot's TextEdit expects.
@(private = "file")
tokenize_line :: proc(s: string, out: ^godot.Dictionary) {
    n := len(s)
    if n == 0 {
        return
    }
    // cols[byte] -> rune column at that byte (so multi-byte runes don't desync columns).
    cols := make([]int, n + 1)
    defer delete(cols)
    {
        col := 0
        i := 0
        for i < n {
            cols[i] = col
            b := s[i]
            size := 1
            if b >= 0xF0 {size = 4} else if b >= 0xE0 {size = 3} else if b >= 0xC0 {size = 2}
            for k in 1 ..< size {
                if i + k < n {cols[i + k] = col}
            }
            col += 1
            i += size
        }
        cols[n] = col
    }

    last := godot.Color{-1, -1, -1, -1} // sentinel: nothing emitted yet
    i := 0
    for i < n {
        b := s[i]
        switch {
        case b == '/' && i + 1 < n && s[i + 1] == '/':
            hl_emit(out, &last, cols[i], C_COMMENT)
            i = n // line comment runs to EOL
        case b == '/' && i + 1 < n && s[i + 1] == '*':
            hl_emit(out, &last, cols[i], C_COMMENT)
            i += 2
            for i < n {
                if s[i] == '*' && i + 1 < n && s[i + 1] == '/' {
                    i += 2
                    break
                }
                i += 1
            }
        case b == '"':
            hl_emit(out, &last, cols[i], C_STRING)
            i += 1
            for i < n {
                if s[i] == '\\' {i += 2;continue}
                if s[i] == '"' {i += 1;break}
                i += 1
            }
        case b == '`':
            hl_emit(out, &last, cols[i], C_STRING)
            i += 1
            for i < n {
                if s[i] == '`' {i += 1;break}
                i += 1
            }
        case b == '\'':
            hl_emit(out, &last, cols[i], C_STRING)
            i += 1
            for i < n {
                if s[i] == '\\' {i += 2;continue}
                if s[i] == '\'' {i += 1;break}
                i += 1
            }
        case is_digit(b):
            hl_emit(out, &last, cols[i], C_NUMBER)
            i += 1
            for i < n && (is_alnum(s[i]) || s[i] == '.' || s[i] == '_') {i += 1}
        case is_alpha(b):
            start := i
            i += 1
            for i < n && is_alnum(s[i]) {i += 1}
            word := s[start:i]
            color := C_TEXT
            if kw, control := is_keyword(word); kw {
                color = control ? C_CONTROL : C_KEYWORD
            } else if word[0] >= 'A' && word[0] <= 'Z' {
                color = C_TYPE // PascalCase identifier -> type
            } else {
                j := i // proc-call: next non-space byte is '('
                for j < n && (s[j] == ' ' || s[j] == '\t') {j += 1}
                if j < n && s[j] == '(' {color = C_FUNC}
            }
            hl_emit(out, &last, cols[start], color)
        case:
            hl_emit(out, &last, cols[i], C_TEXT) // whitespace / operators / punctuation
            i += 1
        }
    }
}

// ---- instance plumbing ----

@(private = "file")
highlighter_create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()
    object := gdext.classdb_construct_object(godot.editor_syntax_highlighter_name_ref())
    self := new(OdinSyntaxHighlighter)
    self.object = object
    gdext.object_set_instance(object, &odin_highlighter_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &highlighter_binding_callbacks)
    return object
}

@(private = "file")
highlighter_free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()
    if instance == nil {
        return
    }
    free(cast(^OdinSyntaxHighlighter)instance)
}

@(private = "file")
highlighter_get_virtual_call_data :: proc "c" (class_user_data: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual(highlighter_virtuals[:], name)
}

// ---- virtuals ----

@(private = "file")
hl_get_name :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring("Odin"))
}

@(private = "file")
hl_get_supported_languages :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(ret, make_psa("Odin")) // matched against OdinLanguage._get_name ("Odin")
}

@(private = "file")
hl_create :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    // The editor clones a fresh highlighter per open editor; hand back a new instance.
    object := gdext.classdb_construct_object(&odin_highlighter_class_name)
    ret_object(ret, object)
}

@(private = "file")
hl_get_line_syntax_highlighting :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()
    self := cast(^OdinSyntaxHighlighter)instance
    out := godot.new_dictionary_default()
    if self != nil {
        line := (cast(^godot.Int)args[0])^
        te := godot.syntax_highlighter_get_text_edit(cast(godot.Syntax_Highlighter)self.object)
        if te != nil {
            ltext := godot.text_edit_get_line(te, line)
            s := string_to_odin(ltext)
            defer delete(s)
            tokenize_line(s, &out)
        }
    }
    (cast(^godot.Dictionary)ret)^ = out
}

// ---- one-time deferred registration (driven by OdinLanguage._frame) ----

@(private = "file")
highlighter_registered: bool
@(private = "file")
highlighter_attempts: int

// Register the OdinSyntaxHighlighter extension class with ClassDB (once). Done lazily in
// the editor (from _frame) so we never register an editor-only parent class in a running
// game.
@(private = "file")
odin_highlighter_register_class :: proc() {
    gdext.string_name_new_with_latin1_chars(&odin_highlighter_class_name, "OdinSyntaxHighlighter", true)

    highlighter_virtuals = make([dynamic]Virtual_Entry, 0, 8)
    append(&highlighter_virtuals, Virtual_Entry{name = "_get_name", fn = hl_get_name})
    append(&highlighter_virtuals, Virtual_Entry{name = "_get_supported_languages", fn = hl_get_supported_languages})
    append(&highlighter_virtuals, Virtual_Entry{name = "_create", fn = hl_create})
    append(&highlighter_virtuals, Virtual_Entry{name = "_get_line_syntax_highlighting", fn = hl_get_line_syntax_highlighting})

    class_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = highlighter_create_instance,
        free_instance_func          = highlighter_free_instance,
        get_virtual_call_data_func  = highlighter_get_virtual_call_data,
        call_virtual_with_data_func = call_virtual_with_data,
        class_userdata              = nil,
    }
    gdext.classdb_register_extension_class2(
        gdext.library,
        &odin_highlighter_class_name,
        godot.editor_syntax_highlighter_name_ref(),
        &class_info,
    )
}

// `OdinLanguage._frame` — deferred, one-time highlighter registration. The ScriptEditor UI
// is not built at extension init, so we wait for the first editor frame where it exists,
// then construct the highlighter and hand it to the ScriptEditor.
lv_frame :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    // Reset the shared godot temp arena FIRST: everything context.temp_allocator handed
    // out since the previous frame dies here (temp allocations are strictly call-local;
    // without this the arena grows unbounded over an editor session).
    gdext.reset_temp_arena()
    // Drive the rebuild-on-save flow on the MAIN thread: if a background scripts build has
    // finished, swap the dll + refresh the Inspector here (reload.odin). Cheap when idle.
    reload_pump_main_thread()
    // Reflect the build's state in the toolbar widget ("building… / FAILED / live ✓") —
    // core/build_status.odin. Runs AFTER the reload pump so a finished build's swap and
    // its green flash land in the same frame. Cheap when idle (mutex peek + enum compare).
    build_status_pump()
    // Deliver freshly-computed async diagnostics to the script editor's red-line UI by
    // nudging a re-validate (validate.odin). Cheap when idle (one mutex check).
    validate_pump_main_thread()
    // If the scripts dll was missing at load (a fresh install with nothing compiled yet),
    // surface ONE actionable editor warning now that the engine/editor are up. No-op after
    // the first warning and outside the editor. Cheap when idle (a single bool check).
    scripts_surface_missing_warning()
    // Push any script registration errors (reflection walk problems recorded at dll init /
    // reload — see runtime/register_class.odin) now that the engine log is up. Drains the
    // list, so each error is pushed once; a no-op when empty.
    scripts_surface_registration_errors()
    // Surface a crash report written by a DYING GAME process (core/crash.odin writes
    // bin/.odin_crash.log; the child's stderr and mid-crash push_error never reach an
    // editor-launched session). Editor-gated inside; cheap when idle (a counter, one
    // stat every ~30 frames). See core/crash_watch.odin (no-op stub on Windows).
    crash_watch_pump()
    // One-shot warning if running on an untested Godot version (the virtual table is pinned).
    check_engine_version_once()
    if highlighter_registered {
        return
    }
    if !bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
        highlighter_registered = true // never needed outside the editor
        return
    }
    highlighter_attempts += 1
    if highlighter_attempts > 1800 { // ~30s @ 60fps safety cap
        highlighter_registered = true
        return
    }

    ei := godot.singleton_editor_interface()
    if ei == nil {
        return // editor UI not up yet — retry next frame
    }
    se := godot.editor_interface_get_script_editor(ei)
    if se == nil {
        return // ScriptEditor not built yet — retry next frame
    }

    odin_highlighter_register_class()
    odin_highlighter_object = gdext.classdb_construct_object(&odin_highlighter_class_name)
    godot.script_editor_register_syntax_highlighter(
        se,
        cast(godot.Editor_Syntax_Highlighter)odin_highlighter_object,
    )
    highlighter_registered = true
    gdext_print("odin: Odin syntax highlighter registered", "ok") // editor_smoke marker
}
