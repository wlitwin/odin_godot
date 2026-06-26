package complete

// ----------------------------------------------------------------------------
// The load-bearing half of OdinLanguage._complete_code: drive the `ols` Odin language
// server over a LIVE-buffer overlay of a script's package and turn its LSP
// `textDocument/completion` reply into structured {label, insert_text, detail, kind}
// records the editor can show.
//
// This mirrors core/diag (the `_validate` engine): the Godot glue lives in
// core/complete.odin (globalize the path, resolve the `ols` binary + collection roots,
// build the result Dictionary); the actual overlay + LSP plumbing + parse lives HERE so it
// can be exercised by a headless unit harness (the `_complete_code` virtual is engine-
// dispatched and NOT callable from GDScript — see tests/complete/). No Godot dependency.
//
// Transport: ols speaks LSP JSON-RPC over stdio. Rather than hold a bidirectional pipe,
// we batch the whole handshake (initialize -> initialized -> didOpen -> completion ->
// shutdown -> exit) into one stdin stream, run `ols` once, and parse every Content-Length
// frame out of its stdout (ols processes the queued messages in order, so the completion
// reply is produced before exit). A fresh spawn per request indexes the package each time
// (~0.5s for the godot collection); that is acceptable for a debounced editor request and
// keeps this exactly as testable + crash-isolated as the `odin check` shell-out validate
// uses. ANY failure returns an empty list — a completion feature must never break the editor.
// ----------------------------------------------------------------------------

import "base:runtime"
import "core:c/libc"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

Completion :: struct {
    label:       string, // owned (cloned) into the caller's allocator
    insert_text: string, // owned — what to type when the option is chosen
    detail:      string, // owned — signature / type hint (may be "")
    kind:        int,    // Godot CodeCompletionKind (see lsp_kind_to_godot)
}

@(private)
counter: int

// U+FFFF — the sentinel `TextEdit::get_text_for_code_completion()` inserts at the caret.
// (Godot hands `_complete_code` the FULL buffer with this marker at the cursor.)
@(private)
CARET_MARKER :: "￿"

// Resolve the caret from the editor-supplied `code`. Godot passes the whole document with a
// U+FFFF marker at the cursor; some callers (and our no-marker tests) instead pass only the
// text UP TO the caret. Handle both: if the marker is present it pins the caret and is
// stripped from the returned source; otherwise the caret is the end of `code`.
//
// Returns 0-based (line, character) for LSP. `character` is counted in bytes, which equals
// UTF-16 units for ASCII source (Odin identifiers) — the practical case for completion.
caret_from_code :: proc(code: string, allocator := context.allocator) -> (clean: string, line: int, char: int) {
    before: string
    if idx := strings.index(code, CARET_MARKER); idx >= 0 {
        before = code[:idx]
        clean = strings.concatenate({before, code[idx + len(CARET_MARKER):]}, allocator)
    } else {
        before = code
        clean = strings.clone(code, allocator)
    }
    line = strings.count(before, "\n")
    if nl := strings.last_index_byte(before, '\n'); nl >= 0 {
        char = len(before[nl + 1:])
    } else {
        char = len(before)
    }
    return
}

// MAX_OPTIONS bounds how many completion options core converts into Godot
// Dictionaries and hands the editor. Each option is ~20 FFI calls to build and
// the editor renders every row, so an unbounded member list — a bare `gd.` is
// the whole ~24k-proc godot API — stalls the editor for 1-2s. Past this many
// MATCHES the user hasn't narrowed enough for the extra rows to be useful; they
// keep typing and the list re-narrows. The editor still fuzzy-filters whatever
// we return.
MAX_OPTIONS :: 256

// `prefix_at_caret` returns the identifier currently being typed — the run of
// [A-Za-z0-9_] immediately before the caret (the U+FFFF marker, or end of buffer
// when absent). `... gd.node2d_set_p<caret>` -> "node2d_set_p"; a bare
// `gd.<caret>` -> "". Used to thin an over-long member list down to what's typed.
prefix_at_caret :: proc(code: string) -> string {
    before := code
    if idx := strings.index(code, CARET_MARKER); idx >= 0 {
        before = code[:idx]
    }
    start := len(before)
    for start > 0 && is_ident_byte(before[start - 1]) {
        start -= 1
    }
    return before[start:]
}

@(private)
is_ident_byte :: proc(c: byte) -> bool {
    return(
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '_' \
    )
}

// `matches_prefix` is a case-insensitive (ASCII) SUBSTRING test used to thin a
// too-large completion list to what the user is typing. An empty prefix matches
// everything (the caller still caps the count). Substring, not strict prefix, so
// typing `set_position` still surfaces `node2d_set_position`.
matches_prefix :: proc(label: string, prefix: string) -> bool {
    if len(prefix) == 0 {return true}
    if len(prefix) > len(label) {return false}
    outer: for i in 0 ..= len(label) - len(prefix) {
        for j in 0 ..< len(prefix) {
            if ascii_lower(label[i + j]) != ascii_lower(prefix[j]) {continue outer}
        }
        return true
    }
    return false
}

@(private)
ascii_lower :: proc(c: byte) -> byte {
    return c + 32 if c >= 'A' && c <= 'Z' else c
}

// Map an LSP CompletionItemKind (1..25) to a Godot CodeCompletionKind:
//   0 CLASS 1 FUNCTION 2 SIGNAL 3 VARIABLE 4 MEMBER 5 ENUM 6 CONSTANT
//   7 NODE_PATH 8 FILE_PATH 9 PLAIN_TEXT
lsp_kind_to_godot :: proc(lsp: int) -> int {
    switch lsp {
    case 2, 3, 4:
        return 1 // Method / Function / Constructor -> FUNCTION
    case 5, 10:
        return 4 // Field / Property -> MEMBER
    case 6:
        return 3 // Variable -> VARIABLE
    case 7, 8, 22:
        return 0 // Class / Interface / Struct -> CLASS
    case 13, 20:
        return 5 // Enum / EnumMember -> ENUM
    case 12, 21:
        return 6 // Value / Constant -> CONSTANT
    case 17:
        return 8 // File -> FILE_PATH
    case:
        return 9 // PLAIN_TEXT
    }
}

// ---- batched LSP message construction (marshalled so strings are JSON-escaped) ----

@(private)
Empty :: struct {}

@(private)
Initialize :: struct {
    jsonrpc: string,
    id:      int,
    method:  string,
    params:  struct {
        processId:    int,
        rootUri:      string,
        capabilities: Empty,
    },
}

@(private)
Notify :: struct {
    jsonrpc: string,
    method:  string,
    params:  Empty,
}

@(private)
DidOpen :: struct {
    jsonrpc: string,
    method:  string,
    params:  struct {
        textDocument: struct {
            uri:        string,
            languageId: string,
            version:    int,
            text:       string,
        },
    },
}

@(private)
CompletionReq :: struct {
    jsonrpc: string,
    id:      int,
    method:  string,
    params:  struct {
        textDocument: struct {
            uri: string,
        },
        position:     struct {
            line:      int,
            character: int,
        },
    },
}

@(private)
ShutdownReq :: struct {
    jsonrpc: string,
    id:      int,
    method:  string,
}

@(private)
frame :: proc(b: ^strings.Builder, payload: []byte) {
    fmt.sbprintf(b, "Content-Length: %d\r\n\r\n", len(payload))
    strings.write_bytes(b, payload)
}

@(private)
add_msg :: proc(b: ^strings.Builder, msg: $T) {
    data, err := json.marshal(msg, {}, context.temp_allocator)
    if err != nil {return}
    frame(b, data)
}

// Build the full stdin stream for one completion request against `uri` at (line, char).
build_batch :: proc(uri: string, text: string, root_uri: string, line: int, char: int, allocator := context.allocator) -> string {
    b := strings.builder_make(allocator)
    add_msg(&b, Initialize{"2.0", 1, "initialize", {processId = 1, rootUri = root_uri, capabilities = {}}})
    add_msg(&b, Notify{"2.0", "initialized", {}})
    add_msg(&b, DidOpen{"2.0", "textDocument/didOpen", {textDocument = {uri = uri, languageId = "odin", version = 1, text = text}}})
    add_msg(&b, CompletionReq{"2.0", 2, "textDocument/completion", {textDocument = {uri = uri}, position = {line = line, character = char}}})
    add_msg(&b, ShutdownReq{"2.0", 3, "shutdown"})
    add_msg(&b, Notify{"2.0", "exit", {}})
    return strings.to_string(b)
}

// ---- response parsing ----

@(private)
as_int :: proc(v: json.Value) -> (int, bool) {
    #partial switch t in v {
    case json.Integer:
        return int(t), true
    case json.Float:
        return int(t), true
    }
    return 0, false
}

@(private)
as_str :: proc(v: json.Value) -> (string, bool) {
    if s, ok := v.(json.String); ok {
        return string(s), true
    }
    return "", false
}

// Scan an ols stdout capture for the `id == 2` (completion) reply and turn its CompletionItems
// into Completion records. Tolerant of `result` being either {items:[...]} or a bare [...].
parse_completion_output :: proc(output: string, allocator := context.allocator) -> [dynamic]Completion {
    res := make([dynamic]Completion, allocator)

    data := transmute([]u8)output
    i := 0
    HDR :: "Content-Length:"
    for {
        // Locate the next Content-Length frame.
        rel := strings.index(string(data[i:]), HDR)
        if rel < 0 {break}
        hs := i + rel + len(HDR)
        // parse the number
        je := strings.index(string(data[hs:]), "\r\n")
        if je < 0 {break}
        num_str := strings.trim_space(string(data[hs:hs + je]))
        length := 0
        for ch in num_str {
            if ch < '0' || ch > '9' {break}
            length = length * 10 + int(ch - '0')
        }
        // body begins after the blank line (\r\n\r\n)
        sep := strings.index(string(data[hs:]), "\r\n\r\n")
        if sep < 0 {break}
        body_start := hs + sep + 4
        body_end := body_start + length
        if body_end > len(data) {break}
        body := data[body_start:body_end]
        i = body_end

        val, perr := json.parse(body, .JSON, true, context.temp_allocator)
        if perr != nil {continue}
        obj, ok := val.(json.Object)
        if !ok {continue}
        idv, has_id := obj["id"]
        if !has_id {continue}
        id, idok := as_int(idv)
        if !idok || id != 2 {continue}

        resv, has_res := obj["result"]
        if !has_res {continue}

        extract_items(&res, resv, allocator)
        return res // first id==2 reply is the answer
    }
    return res
}

// Append every CompletionItem in an LSP completion `result` (either {items:[...]} or a bare
// [...]) to `res` as owned Completion records. Shared by the fresh-spawn stream parser above
// and the persistent-session single-reply parser (parse_completion_reply).
@(private)
extract_items :: proc(res: ^[dynamic]Completion, resv: json.Value, allocator: runtime.Allocator) {
    items: json.Array
    #partial switch t in resv {
    case json.Object:
        if itv, ok2 := t["items"]; ok2 {
            if arr, ok3 := itv.(json.Array); ok3 {items = arr}
        }
    case json.Array:
        items = t
    }

    for itv in items {
        ito, ok2 := itv.(json.Object)
        if !ok2 {continue}
        label, lok := as_str(ito["label"])
        if !lok || label == "" {continue}

        insert := label
        if t, ok3 := as_str(ito["insertText"]); ok3 && t != "" {
            insert = t
        }
        detail, _ := as_str(ito["detail"])
        kind := 9 // PLAIN_TEXT default
        if kv, ok4 := ito["kind"]; ok4 {
            if lk, ok5 := as_int(kv); ok5 {
                kind = lsp_kind_to_godot(lk)
            }
        }
        append(res, Completion{
            label       = strings.clone(label, allocator),
            insert_text = strings.clone(insert, allocator),
            detail      = strings.clone(detail, allocator),
            kind        = kind,
        })
    }
}

// Parse a SINGLE LSP completion response body (one Content-Length frame's JSON) into owned
// Completion records — the persistent-session counterpart to parse_completion_output (which
// scans a whole stdout stream). The reader thread has already extracted the frame body and
// matched its id, so we just pull the items out of `result`.
parse_completion_reply :: proc(body: []u8, allocator := context.allocator) -> [dynamic]Completion {
    res := make([dynamic]Completion, allocator)
    val, perr := json.parse(body, .JSON, true, context.temp_allocator)
    if perr != nil {return res}
    obj, ok := val.(json.Object)
    if !ok {return res}
    resv, has_res := obj["result"]
    if !has_res {return res}
    extract_items(&res, resv, allocator)
    return res
}

// A resolved goto-definition target (LSP textDocument/definition). `path` is a filesystem path
// (file:// stripped); the caller remaps overlay paths + localizes to res://. `line` is 0-based
// (LSP). None/parse-error -> ok=false.
Definition :: struct {
    path: string, // owned (cloned) into the caller's allocator
    line: int,    // 0-based (range.start.line)
    ok:   bool,
}

// Parse a textDocument/definition reply. `result` may be a single Location {uri,range}, an
// array of Location, or an array of LocationLink {targetUri, targetSelectionRange|targetRange}.
// Takes the first; ok=false on null/empty/parse-error.
parse_definition_reply :: proc(body: []u8, allocator := context.allocator) -> Definition {
    val, perr := json.parse(body, .JSON, true, context.temp_allocator)
    if perr != nil {return Definition{}}
    obj, ook := val.(json.Object)
    if !ook {return Definition{}}
    resv, has := obj["result"]
    if !has {return Definition{}}

    loc: json.Object
    #partial switch t in resv {
    case json.Object:
        loc = t
    case json.Array:
        if len(t) > 0 {
            if o, ok2 := t[0].(json.Object); ok2 {loc = o}
        }
    }
    if loc == nil {return Definition{}} // null / empty / unexpected result shape

    // Location: {uri, range}. LocationLink: {targetUri, targetSelectionRange|targetRange}.
    uri := ""
    rng: json.Object
    if u, ok2 := as_str(loc["uri"]); ok2 && u != "" {
        uri = u
        if r, ok3 := loc["range"].(json.Object); ok3 {rng = r}
    } else if u, ok2 := as_str(loc["targetUri"]); ok2 && u != "" {
        uri = u
        if r, ok3 := loc["targetSelectionRange"].(json.Object); ok3 {
            rng = r
        } else if r2, ok4 := loc["targetRange"].(json.Object); ok4 {
            rng = r2
        }
    }
    if uri == "" {return Definition{}}

    line := 0
    if rng != nil {
        if startv, ok3 := rng["start"].(json.Object); ok3 {
            if lv, ok4 := as_int(startv["line"]); ok4 {line = lv}
        }
    }

    path := uri
    if strings.has_prefix(path, "file://") {path = path[len("file://"):]}
    return Definition{path = strings.clone(path, allocator), line = line, ok = true}
}

// ---- the full overlay + ols pipeline ----

// Write the ols.json that tells ols where the collections live, so completion does NOT
// depend on `odin root` (the editor process usually can't reach `odin` either — same trap
// validate hit). `share` is the Odin distribution's share dir (base/core/vendor/shared);
// when empty those entries are omitted (godot-only completion still works for many symbols).
@(private)
write_ols_json :: proc(path: string, root: string, share: string) -> bool {
    b := strings.builder_make(context.temp_allocator)
    strings.write_string(&b, "{\"collections\":[")
    if share != "" {
        fmt.sbprintf(&b, "{{\"name\":\"base\",\"path\":\"%s/base\"}},", share)
        fmt.sbprintf(&b, "{{\"name\":\"core\",\"path\":\"%s/core\"}},", share)
        fmt.sbprintf(&b, "{{\"name\":\"vendor\",\"path\":\"%s/vendor\"}},", share)
        fmt.sbprintf(&b, "{{\"name\":\"shared\",\"path\":\"%s/shared\"}},", share)
    }
    fmt.sbprintf(&b, "{{\"name\":\"godot\",\"path\":\"%s\"}}", root)
    strings.write_string(&b, "],\"enable_snippets\":true,\"enable_hover\":true}")
    return os.write_entire_file(path, transmute([]u8)strings.to_string(b)) == nil
}

// Full LIVE-buffer completion: copy the package dir to a temp overlay, overwrite the edited
// file (basename of `abs_path`) with the caret-resolved buffer, write an ols.json pointing
// the `godot`/base/core/vendor collections at `root`/`share`, run `ols` over a batched LSP
// handshake, and return the completion options at the caret. ANY failure returns an empty
// list — completion must never break/hang the editor.
run_completion :: proc(
    code: string,
    abs_path: string,
    root: string,
    share: string,
    ols_bin := "ols",
    allocator := context.allocator,
) -> [dynamic]Completion {
    empty := make([dynamic]Completion, allocator)

    slash := strings.last_index_byte(abs_path, '/')
    if slash <= 0 {
        return empty
    }
    pkgdir := abs_path[:slash]
    basename := abs_path[slash + 1:]

    clean, line, char := caret_from_code(code, context.temp_allocator)

    tmpdir := os.lookup_env("TMPDIR", context.allocator) or_else strings.clone("/tmp")
    defer delete(tmpdir)
    tmpdir = strings.trim_suffix(tmpdir, "/")

    counter += 1
    work := fmt.aprintf("%s/odin_complete_%d", tmpdir, counter)
    defer delete(work)
    in_file := fmt.aprintf("%s/odin_complete_%d.in", tmpdir, counter)
    defer delete(in_file)
    out_file := fmt.aprintf("%s/odin_complete_%d.out", tmpdir, counter)
    defer delete(out_file)

    // 1. Fresh overlay dir with a copy of every sibling `.odin` (incl. `*.gen.odin`).
    setup := fmt.ctprintf("rm -rf '%s' && mkdir -p '%s' && cp '%s'/*.odin '%s'/ 2>/dev/null", work, work, pkgdir, work)
    if libc.system(setup) != 0 {
        return empty
    }
    defer {
        cleanup := fmt.ctprintf("rm -rf '%s' '%s' '%s'", work, in_file, out_file)
        libc.system(cleanup)
    }

    // 2. ols.json so collections resolve without `odin root`.
    ols_json := fmt.aprintf("%s/ols.json", work)
    defer delete(ols_json)
    if !write_ols_json(ols_json, root, share) {
        return empty
    }

    // 3. Overwrite the edited file with the LIVE (caret-stripped) editor buffer.
    overlay := fmt.aprintf("%s/%s", work, basename)
    defer delete(overlay)
    if werr := os.write_entire_file(overlay, transmute([]u8)clean); werr != nil {
        return empty
    }

    // 4. Build the batched LSP stdin stream and write it.
    uri := fmt.aprintf("file://%s", overlay)
    defer delete(uri)
    root_uri := fmt.aprintf("file://%s", work)
    defer delete(root_uri)
    batch := build_batch(uri, clean, root_uri, line, char, context.temp_allocator)
    if werr := os.write_entire_file(in_file, transmute([]u8)batch); werr != nil {
        return empty
    }

    // 5. Run ols once over the batch (cwd = overlay so it discovers ols.json), capture stdout.
    run := fmt.ctprintf("cd '%s' && '%s' < '%s' > '%s' 2>/dev/null", work, ols_bin, in_file, out_file)
    libc.system(run) // rc ignored: the reply is read from the captured frames

    data, rerr := os.read_entire_file(out_file, context.allocator)
    if rerr != nil {
        return empty
    }
    defer delete(data)

    delete(empty)
    return parse_completion_output(string(data), allocator)
}
