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
import "core:unicode/utf8"

Diagnostic :: struct {
    line:    int,
    column:  int,
    message: string, // owned (cloned) into the caller's allocator
}

// clamp_all — bound every diagnostic into `source`'s valid caret range: 1-based line
// within the text, 1-based column at most one past the line's last rune (the caret-after-
// last-char position GDScript's own diagnostics use). Two real inputs land outside that
// range: odin's EOF-class errors carry column 0 (`file(43:0) Expected '}', got EOF`), and
// package-sibling diagnostics carry positions from a DIFFERENT file than the one the
// editor attributes them to. Godot 4.6 shrugged out-of-range error positions off; 4.7's
// ScriptTextEditor stores errors[0] as (line-1, column-1) and its caret x-offset walk
// indexes the line's char vector with the result UNGUARDED — column 0 becomes -1, wraps
// to a huge unsigned, and the editor dies on a FATAL CowData bounds check (two editor
// crashes reproduced on 4.7.1, 2026-07-25). Every diagnostic that reaches the engine
// must pass through here first.
clamp_all :: proc(ds: []Diagnostic, source: string) {
    caps := make([dynamic]int)
    defer delete(caps)
    rest := source
    for line in strings.split_lines_iterator(&rest) {
        append(&caps, utf8.rune_count_in_string(line) + 1)
    }
    for &d in ds {
        d.line = clamp(d.line, 1, max(len(caps), 1))
        if d.line - 1 < len(caps) {
            d.column = clamp(d.column, 1, caps[d.line - 1])
        } else {
            d.column = 1
        }
    }
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
// `Path does not exist` as a SYNTAX error on the import line — which aborts the whole
// check and takes every real diagnostic with it, so the buffer reports as
// clean-but-for-one-phantom-error.
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
// KEEP IN SYNC with core/complete/complete.odin's copy of this proc — two independent
// editor features, one overlay shape.
overlay_setup_cmd :: proc(
    work, pkgdir: string,
    allocator := context.allocator
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
        q(work), q(ov), q(pkgdir), q(ov)
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
                c2 >= 0 ? rest[:c2] : rest
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
        shell_quote(strings.concatenate({into, "/", name}, context.temp_allocator), context.temp_allocator)
    )
}

// module_root_of — the top of `pkgdir`'s script module: walk up while the PARENT is still
// an Odin package (holds authored `.odin` sources).
//
// This is structural rather than the `res://scripts` / `res://modules/<name>` prefix rule
// the reload coordinator uses, and deliberately so: core/diag holds NO Godot dependency
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
            shell_quote(strings.concatenate({into, "/", fi.name}, context.temp_allocator), context.temp_allocator)
        )
    }
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
    allocator := context.allocator
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

    // 1. Fresh overlay holding a copy of every sibling `.odin` (incl. `*.gen.odin`), laid
    //    out as a mirror of the module tree so relative imports still resolve. The overlay
    //    dir is the edited package's place IN that mirror, not the workspace root.
    setup_cmd, pkg_dir_ov := overlay_setup_cmd(work, pkgdir, context.temp_allocator)
    q_pkg_ov := shell_quote(pkg_dir_ov, context.temp_allocator)
    setup := strings.clone_to_cstring(setup_cmd, context.temp_allocator)
    if libc.system(setup) != 0 {
        return empty
    }
    defer {
        cleanup := fmt.ctprintf("rm -rf %s %s", q_work, shell_quote(out_file, context.temp_allocator))
        libc.system(cleanup)
    }

    // 2. Overwrite the edited file with the LIVE editor buffer.
    overlay := fmt.aprintf("%s/%s", pkg_dir_ov, basename)
    defer delete(overlay)
    if werr := os.write_entire_file(overlay, transmute([]u8)source); werr != nil {
        return empty
    }

    // 3. Type/parse-check the overlay; capture stdout+stderr. NO_COLOR is
    // load-bearing: parse_line matches the literal ") Error:" marker, and an
    // odin that colors its diagnostics (some builds color even into a
    // redirect) threads ANSI escapes right through that marker — every
    // diagnostic silently filters out and validate reports a broken buffer
    // CLEAN. The parser wants machine-readable output; ask for it.
    check := fmt.ctprintf(
		"NO_COLOR=1 %s check %s -collection:godot=%s -no-entry-point -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc -custom-attribute:gd_command -custom-attribute:gd_tick -custom-attribute:gd_input -custom-attribute:gd_sample -custom-attribute:gd_step -custom-attribute:gd_cue -custom-attribute:gd_fact -custom-attribute:gd_half -custom-attribute:gd_message > %s 2>&1",
        shell_quote(odin_bin, context.temp_allocator),
        q_pkg_ov,
        shell_quote(root, context.temp_allocator),
        shell_quote(out_file, context.temp_allocator)
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
