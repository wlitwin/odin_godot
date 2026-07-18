package diag

// ----------------------------------------------------------------------------
// The load-bearing half of OdinLanguage._validate: run `odin check` over a LIVE-buffer
// overlay of a script's package and parse the compiler's diagnostics into structured
// {line, column, message} records.
//
// This is split out from core/validate.odin (which adds the thin Godot glue: globalizing
// the path, resolving the collection root, and building the result Dictionary) precisely
// so it can be exercised by a headless unit harness — the `_validate` virtual itself is
// dispatched by the engine and is NOT callable from GDScript, so the real end-to-end logic
// is proven HERE (see tests/validate/). No Godot dependency lives in this package.
// ----------------------------------------------------------------------------

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

Diagnostic :: struct {
    line:    int,
    column:  int,
    message: string, // owned (cloned) into the caller's allocator
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

// basename of a '/'-separated path (returns a slice of `path`, no allocation).
path_base :: proc(path: string) -> string {
    if idx := strings.last_index_byte(path, '/'); idx >= 0 {
        return path[idx + 1:]
    }
    return path
}

// Parse one Odin diagnostic line:
//   `<path>(<line>:<col>) Error: <message>`
//   `<path>(<line>:<col>) Syntax Error: <message>`
// Source-snippet / caret continuation lines carry no `) Error:` marker, so they don't
// match. Returns ok=false for non-diagnostic lines.
parse_line :: proc(line: string) -> (l: int, c: int, msg: string, file: string, ok: bool) {
    ki := strings.index(line, ") Syntax Error:")
    klen := len(") Syntax Error:")
    if ki < 0 {
        ki = strings.index(line, ") Error:")
        klen = len(") Error:")
    }
    if ki < 0 {
        return 0, 0, "", "", false
    }
    prefix := line[:ki] // "<path>(<line>:<col>"
    lp := strings.last_index_byte(prefix, '(')
    if lp < 0 {
        return 0, 0, "", "", false
    }
    file = prefix[:lp]
    lc := prefix[lp + 1:] // "<line>:<col>"
    colon := strings.index_byte(lc, ':')
    if colon < 0 {
        return 0, 0, "", "", false
    }
    l, _ = strconv.parse_int(lc[:colon])
    c, _ = strconv.parse_int(lc[colon + 1:])
    if l < 1 {l = 1} // some type errors lack a precise loc (0,0) — squiggle at the top
    if c < 1 {c = 1}
    msg = strings.trim_space(line[ki + klen:])
    ok = true
    return
}

// Parse a whole `odin check` capture, keeping only diagnostics for `basename`. Messages
// are cloned into `allocator` (the input may be freed by the caller after this returns).
parse_output :: proc(output: string, basename: string, allocator := context.allocator) -> [dynamic]Diagnostic {
    res := make([dynamic]Diagnostic, allocator)
    it := output
    for line in strings.split_lines_iterator(&it) {
        l, c, msg, file, ok := parse_line(line)
        if !ok {
            continue
        }
        if path_base(file) != basename {
            continue
        }
        append(&res, Diagnostic{line = l, column = c, message = strings.clone(msg, allocator)})
    }
    return res
}

// Full LIVE-buffer pipeline: copy the package dir to a temp overlay, overwrite the edited
// file (basename of abs_path) with `source`, `odin check` the overlay against the `godot`
// collection at `root`, and return the diagnostics for that file. ANY failure (can't copy,
// `odin` missing, etc.) returns an empty list — a validate feature must never break/hang
// the editor. `odin check` is spawned via libc.system (inherits the editor's PATH).
run_check_overlay :: proc(
    source: string,
    abs_path: string,
    root: string,
    odin_bin := "odin",
    allocator := context.allocator,
) -> [dynamic]Diagnostic {
    empty := make([dynamic]Diagnostic, allocator)

    slash := strings.last_index_byte(abs_path, '/')
    if slash <= 0 {
        return empty
    }
    pkgdir := abs_path[:slash]
    basename := abs_path[slash + 1:]

    tmpdir := os.lookup_env("TMPDIR", context.allocator) or_else strings.clone("/tmp")
    defer delete(tmpdir)
    tmpdir = strings.trim_suffix(tmpdir, "/")

    counter += 1
    // PID in the name: two editor instances validating concurrently must not share (and
    // rm -rf) each other's overlay dirs — the counter alone is process-local.
    work := fmt.aprintf("%s/odin_validate_%d_%d", tmpdir, os.get_pid(), counter)
    defer delete(work)
    out_file := fmt.aprintf("%s/odin_validate_%d_%d.out", tmpdir, os.get_pid(), counter)
    defer delete(out_file)

    q_work := shell_quote(work, context.temp_allocator)
    q_pkgdir := shell_quote(pkgdir, context.temp_allocator)

    // 1. Fresh overlay dir holding a copy of every sibling `.odin` (incl. `*.gen.odin`).
    setup := fmt.ctprintf(
        "rm -rf %s && mkdir -p %s && cp %s/*.odin %s/ 2>/dev/null",
        q_work,
        q_work,
        q_pkgdir,
        q_work,
    )
    if libc.system(setup) != 0 {
        return empty
    }
    defer {
        cleanup := fmt.ctprintf("rm -rf %s %s", q_work, shell_quote(out_file, context.temp_allocator))
        libc.system(cleanup)
    }

    // 2. Overwrite the edited file with the LIVE editor buffer.
    overlay := fmt.aprintf("%s/%s", work, basename)
    defer delete(overlay)
    if werr := os.write_entire_file(overlay, transmute([]u8)source); werr != nil {
        return empty
    }

    // 3. Type/parse-check the overlay; capture stdout+stderr.
    check := fmt.ctprintf(
        "%s check %s -collection:godot=%s -no-entry-point -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc -custom-attribute:gd_command -custom-attribute:gd_tick -custom-attribute:gd_sample -custom-attribute:gd_step -custom-attribute:gd_fact > %s 2>&1",
        shell_quote(odin_bin, context.temp_allocator),
        q_work,
        shell_quote(root, context.temp_allocator),
        shell_quote(out_file, context.temp_allocator),
    )
    libc.system(check) // rc ignored: diagnostics are read from the captured output

    data, rerr := os.read_entire_file(out_file, context.allocator)
    if rerr != nil {
        return empty
    }
    defer delete(data)

    delete(empty)
    return parse_output(string(data), basename, allocator)
}
