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
// signatureHelp -> shutdown -> exit) into one stdin stream, run `ols` once, and parse every Content-Length
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

// Quote `s` for a POSIX shell (private mirror of core/common.odin's canonical
// shell_quote — this package must stay Godot/core-free for the unit harness).
@(private)
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

// How far up overlay_setup_cmd will walk looking for the module root. A script module is
// a handful of levels deep at most; the bound is what keeps a pathological tree (or a
// checkout whose every ancestor happens to hold Odin sources) from mirroring the world.
@(private = "file")
MAX_MODULE_DEPTH :: 8

// overlay_setup_cmd — the shell command that builds a live-buffer overlay of `pkgdir`
// inside the fresh workspace `work`, laid out so RELATIVE package imports still resolve.
// Returns the command and the overlay directory the edited file's copy lands in.
//
// A flat copy of one directory's `.odin` files is not enough: a script module is a TREE
// (annotated classes live in subfolders, at any depth), so `import "ui"` from the module
// root, `import "../util"` from a subfolder and `import "../../util"` from a subfolder of
// a subfolder are all ordinary. In a flat overlay they point at nothing, and odin reports
// `Path does not exist` as a SYNTAX error on the import line — which aborts parsing, so
// completion sees a package that does not resolve at all.
//
// So the overlay mirrors the module TREE from its root down to the edited package: every
// directory on that chain is a real directory in the workspace, and at each level every
// non-dot sibling that is NOT on the chain is symlinked. For a module root `m` and an
// edited package `m/ui/widgets`:
//
//   <work>/              real; links to every child of `m`      except `ui`
//   <work>/ui/           real; links to every child of `m/ui`   except `widgets`
//   <work>/ui/widgets/   the edited package's `.odin` files, COPIED (the live buffer
//                        overwrites one of them afterwards), plus links to ITS children
//
// so `../../util` resolves at `<work>/util`, `../sibling` at `<work>/ui/sibling`, and a
// child package at `<work>/ui/widgets/<child>`. Editing the module root itself degenerates
// to `<work>/` holding the copy plus one link per child — the one-level shape.
//
// Only the edited package is copied. Everything reached through a symlink is read from
// DISK, which is exactly right: an unedited package has no live buffer. Dot-directories
// are skipped (`.godot` and friends are never packages).
//
// THE SHARED VOCABULARY TREE. A module may also import `res://shared/<pkg>` — read-only
// types/constants/pure procs every module is allowed to link (scriptgen/shared.odin). That
// import resolves ABOVE the module root (`../shared/ids` from res://scripts,
// `../../shared/ids` from res://modules/<name>), i.e. outside a mirror rooted at the module,
// which is the same phantom `Path does not exist` abort in a new place. So when the project
// has a shared/ tree the chain is extended UPWARD to the project level and `shared` is
// symlinked beside it:
//
//   <work>/shared        -> <project>/shared        (link)
//   <work>/scripts/      real; the module root, laid out as above
//
// Editing a file UNDER shared/ works by the same mechanism from shared/'s parent, so a
// shared package's own `../<sibling>` imports resolve. A project with no shared/ tree
// produces byte-identical commands to before.
//
// KEEP IN SYNC with core/diag/diag.odin's copy of this proc — two independent editor
// features, one overlay shape.
overlay_setup_cmd :: proc(
    work, pkgdir: string,
    allocator := context.allocator,
) -> (cmd: string, overlay_dir: string) {
    mroot := module_root_of(pkgdir)
    rel := pkgdir[min(len(mroot) + 1, len(pkgdir)):] // "" | "ui" | "ui/widgets"
    // `up` is the module root's own path relative to `top` ("" = no extension: the
    // workspace root IS the module root, the pre-shared shape).
    top, up := shared_chain(mroot)
    full_rel := rel
    if up != "" {
        full_rel = rel == "" ? up : strings.concatenate({up, "/", rel}, context.temp_allocator)
    }
    ov :=
        full_rel == "" \
        ? strings.clone(work, allocator) \
        : strings.concatenate({work, "/", full_rel}, allocator)

    b := strings.builder_make(allocator)
    q :: proc(s: string) -> string {return shell_quote(s, context.temp_allocator)}
    fmt.sbprintf(
        &b,
        "rm -rf %s && mkdir -p %s && cp %s/*.odin %s/ 2>/dev/null",
        q(work), q(ov), q(pkgdir), q(ov),
    )
    // The levels ABOVE the module root exist as real directories already (the `mkdir -p`
    // above made the whole chain). They need exactly two links, and deliberately no more:
    // sibling MODULES are never linked, because a module may not import another one.
    if up != "" {
        cut := strings.index_byte(up, '/')
        seg0 := cut >= 0 ? up[:cut] : up
        if seg0 != "shared" {
            // The project level: the shared tree beside the module chain.
            link_one(&b, strings.concatenate({top, "/shared"}, context.temp_allocator), work, "shared")
        } else if cut >= 0 {
            // Editing INSIDE shared/: its sibling packages, so `../<sibling>` resolves.
            rest := up[cut + 1:]
            c2 := strings.index_byte(rest, '/')
            link_dirs(
                &b,
                strings.concatenate({top, "/shared"}, context.temp_allocator),
                strings.concatenate({work, "/shared"}, context.temp_allocator),
                c2 >= 0 ? rest[:c2] : rest,
            )
        }
    }
    // One pass per level of the MODULE chain, root-first. `seg` is the chain's own segment
    // at that level — a real directory in the workspace, so it must not also be a symlink.
    real_dir := mroot
    mirror := up == "" ? work : strings.concatenate({work, "/", up}, context.temp_allocator)
    for {
        cut := strings.index_byte(rel, '/')
        seg := rel
        if cut >= 0 {seg = rel[:cut]}
        link_dirs(&b, real_dir, mirror, seg)
        if seg == "" {break}
        real_dir = strings.concatenate({real_dir, "/", seg}, context.temp_allocator)
        mirror = strings.concatenate({mirror, "/", seg}, context.temp_allocator)
        rel = cut >= 0 ? rel[cut + 1:] : ""
    }
    return strings.to_string(b), ov
}

// shared_chain — where the workspace must be rooted so `res://shared` is reachable, and
// the module root's path relative to it. Returns ("", "") when the shared tree is not in
// play, which keeps every flat/no-shared project on exactly the old one-module layout.
//
// Structural, like module_root_of (this package stays Godot-free): the project dir is the
// module root's PARENT, or its GRANDPARENT when that parent is `modules`. A file being
// edited inside the shared tree is recognized the same way, from `shared` appearing as the
// module root or as its parent.
@(private = "file")
shared_chain :: proc(mroot: string) -> (top: string, up: string) {
    parent := parent_dir(mroot)
    if parent == "" {return "", ""}
    base := path_base(mroot)
    pbase := path_base(parent)
    // res://modules/<name> — checked first, so a module that happens to be NAMED `shared`
    // is still a module.
    if pbase == "modules" {
        gp := parent_dir(parent)
        if gp == "" || !is_dir(strings.concatenate({gp, "/shared"}, context.temp_allocator)) {
            return "", ""
        }
        return gp, strings.concatenate({"modules/", base}, context.temp_allocator)
    }
    if base == "shared" {return parent, "shared"} // the shared tree root is itself a package
    if pbase == "shared" {
        gp := parent_dir(parent)
        if gp == "" {return "", ""}
        return gp, strings.concatenate({"shared/", base}, context.temp_allocator)
    }
    if !is_dir(strings.concatenate({parent, "/shared"}, context.temp_allocator)) {return "", ""}
    return parent, base
}

// The last '/'-separated segment of `path` (core/diag has the same helper; this package
// keeps its own so neither depends on the other).
@(private = "file")
path_base :: proc(path: string) -> string {
    if idx := strings.last_index_byte(path, '/'); idx >= 0 {
        return path[idx + 1:]
    }
    return path
}

// The parent directory of `path` ("" when there is none / it is a root segment).
@(private = "file")
parent_dir :: proc(path: string) -> string {
    idx := strings.last_index_byte(path, '/')
    if idx <= 0 {return ""}
    return path[:idx]
}

@(private = "file")
is_dir :: proc(path: string) -> bool {
    fi, err := os.stat(path, context.temp_allocator)
    return err == nil && fi.type == .Directory
}

// `ln -s <target> <into>/<name>` for ONE directory (the shared tree beside the module
// chain). Silent on failure, like link_dirs: a missing link only costs the resolution it
// would have provided.
@(private = "file")
link_one :: proc(b: ^strings.Builder, target, into, name: string) {
    if !is_dir(target) {
        return
    }
    fmt.sbprintf(
        b,
        " ; ln -s %s %s 2>/dev/null",
        shell_quote(target, context.temp_allocator),
        shell_quote(strings.concatenate({into, "/", name}, context.temp_allocator), context.temp_allocator),
    )
}

// module_root_of — the top of `pkgdir`'s script module: walk up while the PARENT is still
// an Odin package (holds authored `.odin` sources).
//
// This is structural rather than the `res://scripts` / `res://modules/<name>` prefix rule
// the reload coordinator uses, and deliberately so: core/complete holds NO Godot dependency
// (that is what lets the headless harness drive the real code path), so it has no
// ProjectSettings to globalize `res://` against. The structural walk lands on the same
// directory in every layout the toolchain supports, because a module root's parent is
// either the project directory or `modules/` — and neither is an Odin package. If the walk
// finds nothing above `pkgdir`, the result is `pkgdir` itself and the layout degenerates
// to the flat one-level overlay.
@(private = "file")
module_root_of :: proc(pkgdir: string) -> string {
    root := pkgdir
    for _ in 0 ..< MAX_MODULE_DEPTH {
        idx := strings.last_index_byte(root, '/')
        if idx <= 0 {break}
        parent := root[:idx]
        if !has_authored_odin(parent) {break}
        root = parent
    }
    return root
}

// Does `dir` hold at least one AUTHORED `.odin` (a generated artifact does not make a
// directory a package — a dir left holding only `*.gen.odin` is a sweep target)?
@(private = "file")
has_authored_odin :: proc(dir: string) -> bool {
    fis, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
    if err != nil {
        return false
    }
    for fi in fis {
        if fi.type == .Directory {continue}
        if strings.has_suffix(fi.name, ".odin") && !strings.has_suffix(fi.name, ".gen.odin") {
            return true
        }
    }
    return false
}

// Append one `ln -s` per non-dot subdirectory of `from` into `into`, skipping `except`
// (the chain's own next level, which is a real directory rather than a link). Failures
// are swallowed: a missing link only costs the resolution it would have provided.
@(private = "file")
link_dirs :: proc(b: ^strings.Builder, from, into, except: string) {
    fis, err := os.read_directory_by_path(from, -1, context.temp_allocator)
    if err != nil {
        return
    }
    for fi in fis {
        if fi.type != .Directory || strings.has_prefix(fi.name, ".") || fi.name == except {
            continue
        }
        fmt.sbprintf(
            b,
            " ; ln -s %s %s 2>/dev/null",
            shell_quote(fi.fullpath, context.temp_allocator),
            shell_quote(strings.concatenate({into, "/", fi.name}, context.temp_allocator), context.temp_allocator),
        )
    }
}

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

// Shared shape for the position-bearing requests (textDocument/completion and
// textDocument/signatureHelp — both take {textDocument, position}).
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

// The request ids used inside the batched stream. SIG_ID rides along AFTER the completion
// request (ols answers the queued messages in order) so one spawn serves both replies.
@(private)
COMPLETION_ID :: 2
@(private)
SIG_ID :: 4

// Build the full stdin stream for one completion request against `uri` at (line, char).
// A textDocument/signatureHelp request (id SIG_ID) is batched alongside the completion so
// the same one-shot ols spawn also yields the editor call hint — when the caret is not
// inside a call ols answers it with `result: null`, which parses to an empty hint.
build_batch :: proc(uri: string, text: string, root_uri: string, line: int, char: int, allocator := context.allocator) -> string {
    b := strings.builder_make(allocator)
    add_msg(&b, Initialize{"2.0", 1, "initialize", {processId = 1, rootUri = root_uri, capabilities = {}}})
    add_msg(&b, Notify{"2.0", "initialized", {}})
    add_msg(&b, DidOpen{"2.0", "textDocument/didOpen", {textDocument = {uri = uri, languageId = "odin", version = 1, text = text}}})
    add_msg(&b, CompletionReq{"2.0", COMPLETION_ID, "textDocument/completion", {textDocument = {uri = uri}, position = {line = line, character = char}}})
    add_msg(&b, CompletionReq{"2.0", SIG_ID, "textDocument/signatureHelp", {textDocument = {uri = uri}, position = {line = line, character = char}}})
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

// Scan an ols stdout capture for the reply frame with `want_id` and return its `result`
// json.Value (parsed into `parse_allocator`). found=false when no such reply exists.
@(private)
find_reply_result :: proc(output: string, want_id: int, parse_allocator: runtime.Allocator) -> (resv: json.Value, found: bool) {
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

        val, perr := json.parse(body, .JSON, true, parse_allocator)
        if perr != nil {continue}
        obj, ok := val.(json.Object)
        if !ok {continue}
        idv, has_id := obj["id"]
        if !has_id {continue}
        id, idok := as_int(idv)
        if !idok || id != want_id {continue}

        resv, has_res := obj["result"]
        if !has_res {continue}
        return resv, true // first matching reply is the answer
    }
    return nil, false
}

// Scan an ols stdout capture for the completion reply and turn its CompletionItems into
// Completion records. Tolerant of `result` being either {items:[...]} or a bare [...].
parse_completion_output :: proc(output: string, allocator := context.allocator) -> [dynamic]Completion {
    res := make([dynamic]Completion, allocator)
    if resv, found := find_reply_result(output, COMPLETION_ID, context.temp_allocator); found {
        extract_items(&res, resv, allocator)
    }
    return res
}

// Scan an ols stdout capture for the signatureHelp reply and format it as a Godot code-hint
// string (see signature_help_to_hint). Owned by `allocator`; "" (allocated) when the reply is
// missing, null (caret not in a call), or malformed — the hint must never break completion.
parse_signature_help_output :: proc(output: string, allocator := context.allocator) -> string {
    if resv, found := find_reply_result(output, SIG_ID, context.temp_allocator); found {
        return signature_help_to_hint(resv, allocator)
    }
    return strings.clone("", allocator)
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

// ---- signature help (the editor call hint) ----------------------------------
//
// Godot's CodeEdit renders `set_code_hint` (fed from `_complete_code`'s `call_hint`) as:
//   * one signature per '\n'-separated line (scene/gui/code_edit.cpp splits on "\n"),
//   * the ACTIVE PARAMETER wrapped in a pair of U+FFFF chars — CodeEdit underlines/highlights
//     the span between the line's first and last 0xFFFF and strips the markers before drawing
//     (code_edit.cpp `line.find/rfind(String::chr(0xFFFF))` + `line.remove_char(0xFFFF)`).
// GDScript emits exactly this from _make_arguments_hint (modules/gdscript/gdscript_editor.cpp):
// "Type name(a: int, ￿b: int = 0￿)". We reproduce that format from ols's LSP
// SignatureHelp reply so Odin engine-binding calls get REAL parameter tooltips (the Odin
// signature has an explicit self/singleton first arg the Godot class docs hide).

// `in_call_context` reports whether the caret sits inside an UNCLOSED call's argument list —
// a cheap syntactic gate that lets core skip the extra warm signatureHelp round-trip when the
// caret is obviously not in a call. Scans BACKWARDS from the caret (the U+FFFF marker, or end
// of buffer): `)` opens nesting, `(` closes it; the first unmatched `(` means in-call. A
// `{`/`}`/`;` at depth 0 is a statement/block boundary — stop there (calls DO span newlines,
// so newlines never stop the scan). Strings/comments are not lexed: a paren inside a string
// can mislead this, costing only a wasted (null-answered) signatureHelp request or a missing
// hint — never a wrong one (ols does the real reasoning). Scan bounded to the last 4 KiB.
in_call_context :: proc(code: string) -> bool {
    before := code
    if idx := strings.index(code, CARET_MARKER); idx >= 0 {
        before = code[:idx]
    }
    SCAN_LIMIT :: 4096
    stop := 0
    if len(before) > SCAN_LIMIT {stop = len(before) - SCAN_LIMIT}
    depth := 0
    for i := len(before) - 1; i >= stop; i -= 1 {
        switch before[i] {
        case ')':
            depth += 1
        case '(':
            if depth == 0 {return true}
            depth -= 1
        case '{', '}', ';':
            if depth == 0 {return false}
        }
    }
    return false
}

// Locate the byte span of the `active`-th parameter inside a signature `label`, walking
// `parameters[].label` in order. Each parameter label is either a SUBSTRING of the signature
// label (ols's form — matched left-to-right starting after the '(' so duplicate texts resolve
// to the right occurrence) or an LSP `[start, end]` offset pair (UTF-16 units == bytes for
// the ASCII signatures ols emits). ok=false when anything is out of shape — the caller then
// shows the signature without a highlight rather than a wrong one.
@(private)
param_span :: proc(label: string, params_v: json.Value, active: int) -> (start, end: int, ok: bool) {
    params, pok := params_v.(json.Array)
    if !pok || active < 0 || active >= len(params) {return 0, 0, false}
    search_from := strings.index_byte(label, '(') + 1 // 0 when the label has no '('
    for p_v, i in params {
        if i > active {break}
        po, ook := p_v.(json.Object)
        if !ook {return 0, 0, false}
        lv, has := po["label"]
        if !has {return 0, 0, false}
        #partial switch t in lv {
        case json.String:
            s := string(t)
            if s == "" {return 0, 0, false}
            rel := strings.index(label[search_from:], s)
            if rel < 0 {return 0, 0, false}
            start = search_from + rel
            end = start + len(s)
            search_from = end
        case json.Array:
            if len(t) != 2 {return 0, 0, false}
            s0, k0 := as_int(t[0])
            e0, k1 := as_int(t[1])
            if !k0 || !k1 {return 0, 0, false}
            start, end = s0, e0
        case:
            return 0, 0, false
        }
    }
    if start < 0 || end > len(label) || start >= end {return 0, 0, false}
    return start, end, true
}

// Convert a parsed LSP SignatureHelp `result` value into Godot's code-hint string (see the
// format note above): '\n'-joined signature labels, with the active signature's active
// parameter wrapped in U+FFFF markers. Returns an owned (possibly empty) string; null /
// malformed results format to "" — CodeEdit treats an empty hint as "no tooltip".
signature_help_to_hint :: proc(resv: json.Value, allocator := context.allocator) -> string {
    obj, ook := resv.(json.Object)
    if !ook {return strings.clone("", allocator)} // null result: caret not in a call
    sigs, aok := obj["signatures"].(json.Array)
    if !aok || len(sigs) == 0 {return strings.clone("", allocator)}

    active_sig, _ := as_int(obj["activeSignature"]) // absent -> 0 (the LSP default)
    active_param_top, _ := as_int(obj["activeParameter"])

    b := strings.builder_make(allocator)
    emitted := 0
    for sig_v, i in sigs {
        sig, sok := sig_v.(json.Object)
        if !sok {continue}
        label, lok := as_str(sig["label"])
        if !lok || label == "" {continue}
        if emitted > 0 {strings.write_string(&b, "\n")}
        emitted += 1
        if i != active_sig {
            strings.write_string(&b, label)
            continue
        }
        // Per-signature activeParameter (LSP 3.16+) overrides the top-level one.
        ap := active_param_top
        if v, k := as_int(sig["activeParameter"]); k {ap = v}
        if start, end, found := param_span(label, sig["parameters"], ap); found {
            strings.write_string(&b, label[:start])
            strings.write_string(&b, CARET_MARKER)
            strings.write_string(&b, label[start:end])
            strings.write_string(&b, CARET_MARKER)
            strings.write_string(&b, label[end:])
        } else {
            strings.write_string(&b, label)
        }
    }
    return strings.to_string(b)
}

// Parse a SINGLE LSP signatureHelp response body (one frame's JSON) into the Godot code-hint
// string — the persistent-session counterpart to parse_signature_help_output. Owned by
// `allocator`; "" on null/malformed (never breaks completion).
parse_signature_help_reply :: proc(body: []u8, allocator := context.allocator) -> string {
    val, perr := json.parse(body, .JSON, true, context.temp_allocator)
    if perr != nil {return strings.clone("", allocator)}
    obj, ok := val.(json.Object)
    if !ok {return strings.clone("", allocator)}
    resv, has_res := obj["result"]
    if !has_res {return strings.clone("", allocator)}
    return signature_help_to_hint(resv, allocator)
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
// handshake, and return the completion options at the caret PLUS the Godot-format call hint
// (`call_hint` is owned by `allocator`; "" when the caret is not inside a call — the
// signatureHelp request rides the same batch, see build_batch). ANY failure returns an empty
// list + empty hint — completion must never break/hang the editor.
run_completion :: proc(
    code: string,
    abs_path: string,
    root: string,
    share: string,
    ols_bin := "ols",
    allocator := context.allocator,
) -> (opts: [dynamic]Completion, call_hint: string) {
    empty := make([dynamic]Completion, allocator)
    no_hint := strings.clone("", allocator)

    slash := strings.last_index_byte(abs_path, '/')
    if slash <= 0 {
        return empty, no_hint
    }
    pkgdir := abs_path[:slash]
    basename := abs_path[slash + 1:]

    clean, line, char := caret_from_code(code, context.temp_allocator)

    tmpdir := os.lookup_env("TMPDIR", context.allocator) or_else strings.clone("/tmp")
    defer delete(tmpdir)
    tmpdir = strings.trim_suffix(tmpdir, "/")

    counter += 1
    // PID in the name: two editor instances must not share (and rm -rf) each other's dirs.
    work := fmt.aprintf("%s/odin_complete_%d_%d", tmpdir, os.get_pid(), counter)
    defer delete(work)
    in_file := fmt.aprintf("%s/odin_complete_%d_%d.in", tmpdir, os.get_pid(), counter)
    defer delete(in_file)
    out_file := fmt.aprintf("%s/odin_complete_%d_%d.out", tmpdir, os.get_pid(), counter)
    defer delete(out_file)

    q_work := shell_quote(work, context.temp_allocator)

    // 1. Fresh overlay with a copy of every sibling `.odin` (incl. `*.gen.odin`), laid out
    //    as a mirror of the module tree so relative imports still resolve. The overlay dir
    //    is the edited package's place IN that mirror, not the workspace root.
    setup_cmd, pkg_dir_ov := overlay_setup_cmd(work, pkgdir, context.temp_allocator)
    setup := strings.clone_to_cstring(setup_cmd, context.temp_allocator)
    if libc.system(setup) != 0 {
        return empty, no_hint
    }
    defer {
        cleanup := fmt.ctprintf(
            "rm -rf %s %s %s",
            q_work,
            shell_quote(in_file, context.temp_allocator),
            shell_quote(out_file, context.temp_allocator),
        )
        libc.system(cleanup)
    }

    // 2. ols.json so collections resolve without `odin root`.
    ols_json := fmt.aprintf("%s/ols.json", work)
    defer delete(ols_json)
    if !write_ols_json(ols_json, root, share) {
        return empty, no_hint
    }

    // 3. Overwrite the edited file with the LIVE (caret-stripped) editor buffer.
    overlay := fmt.aprintf("%s/%s", pkg_dir_ov, basename)
    defer delete(overlay)
    if werr := os.write_entire_file(overlay, transmute([]u8)clean); werr != nil {
        return empty, no_hint
    }

    // 4. Build the batched LSP stdin stream and write it.
    uri := fmt.aprintf("file://%s", overlay)
    defer delete(uri)
    root_uri := fmt.aprintf("file://%s", work)
    defer delete(root_uri)
    batch := build_batch(uri, clean, root_uri, line, char, context.temp_allocator)
    if werr := os.write_entire_file(in_file, transmute([]u8)batch); werr != nil {
        return empty, no_hint
    }

    // 5. Run ols once over the batch (cwd = overlay so it discovers ols.json), capture stdout.
    run := fmt.ctprintf(
        "cd %s && %s < %s > %s 2>/dev/null",
        q_work,
        shell_quote(ols_bin, context.temp_allocator),
        shell_quote(in_file, context.temp_allocator),
        shell_quote(out_file, context.temp_allocator),
    )
    libc.system(run) // rc ignored: the reply is read from the captured frames

    data, rerr := os.read_entire_file(out_file, context.allocator)
    if rerr != nil {
        return empty, no_hint
    }
    defer delete(data)

    delete(empty)
    delete(no_hint, allocator)
    return parse_completion_output(string(data), allocator), parse_signature_help_output(string(data), allocator)
}
