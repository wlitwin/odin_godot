package scriptgen

// ----------------------------------------------------------------------------
// res://shared/ — the READ-ONLY VOCABULARY every script module may import.
//
// Script modules are isolated packages (one dll each) and may not import one
// another. The hazard that rule exists for is precise: a package linked into two
// dlls gets its OWN COPY of every mutable package global, so a write through one
// module's copy is invisible to the other and the "shared" state silently forks.
//
// Duplicated TYPES, CONSTANTS and PURE PROCS carry no such hazard — two copies of
// an enum, a payload struct or a `clamp01` proc are indistinguishable. So one tree
// is exempt from the isolation rule: any package under `<project>/shared/` may be
// imported by any script module (root package or subpackage, at any depth), which
// gives modules a common vocabulary — entity id enums, message payload structs,
// tuning constants, pure helpers — without reopening the forked-state hole.
//
// The exemption is only safe while the tree really is state-free, so scriptgen
// VERIFIES every shared package a module actually imports (following shared ->
// shared imports transitively; unimported directories are nobody's business):
//
//   * no file-scope mutable variables (`x := …` / `x: T` / `x: T = …`, including
//     `@(thread_local)`) and no `@(static)` locals — those are the per-dll copies;
//   * no `@(init)` / `@(fini)` — they would run once PER DLL;
//   * no `//gd:` markers and no `@(gd_*)` procs — scripts are attachable classes
//     and belong to a module; shared/ is engine-agnostic vocabulary;
//   * imports: collections (godot:/core:/base:/vendor:) and other packages under
//     shared/ ONLY. A shared package importing a MODULE is the forked-globals
//     hazard verbatim — that module package would be linked into every dll that
//     imports the shared one.
//
// Every refusal names the file, the line, and the reason. The build scripts keep a
// fast grep backstop for the import half (check_module_isolation in
// build/common.sh, ported in build/build_scripts.ps1); THIS is the structural
// check, and the only one that can see inside the shared tree.
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:os"
import "core:slice"
import "core:strings"

// The absolute `<project>/shared` directory for the module being generated ("" =
// unknown, which disables the exemption entirely). Set once by main() from the
// module root; see shared_root_of.
g_shared_root: string

// Shared package dir -> the import site that first reached it (diagnostics for a
// package that turns out to be missing or stateful). Seeded by check_import,
// extended by the transitive walk in verify_shared_tree.
g_shared_imports: map[string]Loc
g_shared_checked: map[string]bool

// shared_root_of — `<project>/shared` derived from a module root, structurally.
// The project dir is the module root's PARENT (`<project>/scripts`), or its
// GRANDPARENT when that parent is `modules` (`<project>/modules/<name>`). Returns
// "" when the walk runs out of path.
shared_root_of :: proc(module_root: string) -> string {
	root := strings.trim_suffix(norm_path(module_root), "/")
	parent := dir_of(root)
	if parent == "" || parent == root {return ""}
	if path_base(parent) == "modules" {
		gp := dir_of(parent)
		if gp == "" || gp == parent {return ""}
		parent = gp
	}
	return strings.concatenate({parent, "/shared"})
}

// Does an already-resolved absolute import path land in the shared tree (the tree
// root itself, or any package under it)?
under_shared :: proc(resolved: string) -> bool {
	if g_shared_root == "" {return false}
	if resolved == g_shared_root {return true}
	return strings.has_prefix(resolved, strings.concatenate({g_shared_root, "/"}, context.temp_allocator))
}

// shared_import_dir — the directory a RELATIVE import in `file` resolves to, when
// it lands in the shared tree. ok=false for collection imports, for a file with no
// path, and for anything outside shared/ (the caller leaves those alone).
shared_import_dir :: proc(file: ^ast.File, ipath: string) -> (string, bool) {
	if g_shared_root == "" || file.fullpath == "" {return "", false}
	if strings.contains_rune(ipath, ':') {return "", false}
	resolved := resolve_lexical(dir_of(file.fullpath), ipath)
	if !under_shared(resolved) {return "", false}
	return resolved, true
}

// Record a shared package a module (or another shared package) imports, so the
// verification pass below covers exactly the packages that are actually reachable.
note_shared_import :: proc(dir: string, loc: Loc) {
	if _, seen := g_shared_imports[dir]; seen {return}
	g_shared_imports[strings.clone(dir)] = loc
}

// The sentence every shared-tree refusal ends with — one place to say WHY.
@(private = "file")
shared_why :: proc() {
	fmt.eprintln("  res://shared/ is READ-ONLY VOCABULARY: types, constants (X :: …) and pure procs.")
	fmt.eprintln("  It is linked into EVERY module that imports it, and each dll gets its own copy of")
	fmt.eprintln("  any package state — so mutable globals there would silently fork per module. Keep")
	fmt.eprintln("  state in exactly one module (or behind an autoload the modules reach through the")
	fmt.eprintln("  engine); keep the vocabulary they agree on here.")
}

// verify_shared_tree — check every shared package this module's tree imports, plus
// everything they import in turn. Breadth-first over a worklist so a shared package
// importing a sibling shared package is verified too, exactly once.
verify_shared_tree :: proc() {
	queue := make([dynamic]string, context.allocator)
	defer delete(queue)
	// Sorted seed: the diagnostics of a tree with several bad packages come out in a
	// stable order run to run (map iteration order is not).
	for dir in g_shared_imports {append(&queue, dir)}
	slice.sort(queue[:])
	for i := 0; i < len(queue); i += 1 {
		dir := queue[i]
		if g_shared_checked[dir] {continue}
		g_shared_checked[dir] = true
		verify_shared_pkg(dir, g_shared_imports[dir], &queue)
	}
}

// One shared package: every authored source in it must be state-free, script-free
// and import only collections / other shared packages. `from` is where the import
// that reached this package was written (the only location available when the
// package itself turns out not to exist).
@(private = "file")
verify_shared_pkg :: proc(dir: string, from: Loc, queue: ^[dynamic]string) {
	dir_fh, oerr := os.open(dir)
	if oerr != nil {
		error_at(from, "shared import resolves to %q, which is not a readable directory", dir)
		return
	}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {
		error_at(from, "shared import resolves to %q, which is not a readable directory", dir)
		return
	}
	authored := 0
	// Sorted for deterministic diagnostics across filesystems.
	slice.sort_by(files, proc(a, b: os.File_Info) -> bool {return a.name < b.name})
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		authored += 1
		src_bytes, rerr := os.read_entire_file_from_path(fi.fullpath, context.allocator)
		if rerr != nil {
			error_at(Loc{path = fi.fullpath}, "cannot read shared package source")
			continue
		}
		verify_shared_file(fi.fullpath, string(src_bytes), queue)
	}
	if authored == 0 {
		error_at(
			from,
			"shared import resolves to %q, which holds no authored .odin sources — a shared package is an ordinary Odin package under the project's shared/ tree",
			dir
		)
	}
}

// One shared source file. Everything here is a HARD error: a shared package that
// carries state (or a script) is exactly the hazard the module-isolation rule
// exists for, and silently ignoring the declaration would fork it per dll.
@(private = "file")
verify_shared_file :: proc(path, src: string, queue: ^[dynamic]string) {
	rel := shared_rel(path)

	// 1. `//gd:` markers — a text scan, exactly like the loader's (no parse needed,
	//    and a marker in a file that doesn't parse still deserves the real error).
	{
		it := src
		line := 0
		for l in strings.split_lines_iterator(&it) {
			line += 1
			t := strings.trim_space(l)
			if !strings.has_prefix(t, "//gd:") {continue}
			error_at(
				Loc{path, line},
				"the shared package file %s carries the script marker %q — an attachable script class belongs to a MODULE (res://scripts or res://modules/<name>), never to res://shared/, which is engine-agnostic vocabulary every module links",
				rel, t
			)
			shared_why()
			break // one per file is enough to make the point
		}
	}

	// 2. `@(static)` locals — package state wearing a proc-local disguise; the same
	//    per-dll copy, invisible to the file-scope walk below.
	{
		it := src
		line := 0
		for l in strings.split_lines_iterator(&it) {
			line += 1
			t := strings.trim_space(l)
			if !strings.has_prefix(t, "@(static") {continue}
			error_at(
				Loc{path, line},
				"the shared package file %s declares an @(static) local — that is package STATE with a proc-local spelling, and every module that links this package gets its own copy",
				rel
			)
			shared_why()
			break
		}
	}

	file := ast.File {
		fullpath = path,
		src      = src
	}
	p := parser.default_parser()
	p.err = silent_shared_diag
	p.warn = silent_shared_diag
	if !parser.parse_file(&p, &file) {
		return // unparseable — `odin build` reports it properly; don't double-print
	}

	// 3. Imports: collections and other shared packages only.
	file_dir := dir_of(path)
	for imp in file.imports {
		ipath := strings.trim(imp.fullpath, "\"")
		loc := Loc{path, imp.pos.line}
		if strings.contains_rune(ipath, ':') {continue} // a collection — never module-local
		if strings.has_prefix(ipath, "/") || strings.has_prefix(ipath, "\\") {
			error_at(
				loc,
				"the shared package file %s imports the absolute path %q — a shared package may import collections (godot:/core:/base:/vendor:) and other packages under the shared tree (%s) only",
				rel, ipath, g_shared_root
			)
			shared_why()
			continue
		}
		resolved := resolve_lexical(file_dir, ipath)
		if under_shared(resolved) {
			note_shared_import(resolved, loc)
			append(queue, resolved)
			continue
		}
		error_at(
			loc,
			"the shared package file %s imports %q, which resolves to %q OUTSIDE the shared tree (%s) — if that is a script module, this is the forked-globals hazard verbatim: the module's package would be linked into every dll that imports this shared package, duplicating its globals. A shared package may import collections (godot:/core:/base:/vendor:) and other shared packages only",
			rel, ipath, resolved, g_shared_root
		)
		shared_why()
	}

	// 4. File-scope declarations: mutable variables, @(init)/@(fini), @(gd_*) procs.
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok {continue}
		name := "" // the first declared name, for the message
		line := vd.pos.line
		if len(vd.names) > 0 {
			if ident, iok := vd.names[0].derived.(^ast.Ident); iok && ident != nil {
				name = ident.name
				line = ident.pos.line
			}
		}
		if vd.is_mutable {
			error_at(
				Loc{path, line},
				"the shared package file %s declares the file-scope variable %q — every module that links this package gets its OWN copy of it, so writes from one module never reach the other and the state silently forks. Constants (%s :: …), types and pure procs are fine here",
				rel, name, name
			)
			shared_why()
			continue
		}
		for a in ONCE_PER_DLL_ATTRS {
			if !has_attr(vd, a) {continue}
			error_at(
				Loc{path, line},
				"the shared package file %s declares the @(%s) proc %q — it would run ONCE PER DLL (every module that links this package runs it again, over that dll's own copy of the package). Initialization belongs to the module that owns the state",
				rel, a, name
			)
			shared_why()
		}
		for a in GD_ATTRS {
			if !has_attr(vd, a) {continue}
			error_at(
				Loc{path, line},
				"the shared package file %s declares the @(%s) proc %q — the @(gd_*) surface is a script module's contract with the engine (and, for the kit attributes, with the wire); res://shared/ is engine-agnostic vocabulary every module links. Move the proc into the module, keeping the types and constants it needs here",
				rel, a, name
			)
			shared_why()
			break
		}
	}
}

// The attributes whose whole point is "run me once", which in a package linked
// into N dlls means N times, each over that dll's own copy of the package.
@(private = "file")
ONCE_PER_DLL_ATTRS := [?]string{"init", "fini"}

// The `@(gd_*)` attribute set scriptgen understands — the same list build/common.sh
// passes to `odin build` as -custom-attribute flags (ODIN_GD_ATTRS). A shared file
// wearing any of them is refused loudly rather than ignored silently.
@(private = "file")
GD_ATTRS := [?]string {
	"gd_method",
	"gd_connect",
	"gd_rpc",
	"gd_command",
	"gd_tick",
	"gd_input",
	"gd_sample",
	"gd_step",
	"gd_event",
	"gd_cue",
	"gd_fact",
	"gd_half",
	"gd_message"
}

// Path of a shared source relative to the shared tree root (`ids/ids.odin`) — the
// spelling an author recognizes. Falls back to the full path if it is somehow not
// under the root.
@(private = "file")
shared_rel :: proc(path: string) -> string {
	p := norm_path(path)
	if g_shared_root != "" {
		pre := strings.concatenate({g_shared_root, "/"}, context.temp_allocator)
		if strings.has_prefix(p, pre) {return p[len(pre):]}
	}
	return p
}

@(private = "file")
silent_shared_diag :: proc(pos: tokenizer.Pos, format: string, args: ..any) {}
