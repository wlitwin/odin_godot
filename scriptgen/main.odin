package scriptgen

// ----------------------------------------------------------------------------
// scriptgen — the Phase 3.5 codegen preprocessor for odin_godot.
//
// Authors write a CLEAN `.odin` script (struct-tag exports, plain typed lifecycle
// /method procs, `//gd:` markers). For each such file `scriptgen` emits a sibling
// `<name>.gen.odin` (same package) containing the verbose Phase-3 registration
// boilerplate that those scripts otherwise hand-write: the uniform Variant
// trampolines, the `@(private="file")` backing arrays, the signal-emit helpers, and
// the `@(init) rt.register(Class_Desc{...})`. The generated output is byte-for-byte
// EQUIVALENT in effect to the hand-written Phase-3 showcase scripts.
//
// SINGLE-FILE AUTHORING: the authored `.odin` is the file the user attaches to a node
// (the loader reads its `//gd:class` marker to bind it to the compiled class). scriptgen
// emits ONLY the `<name>.gen.odin` build artifact beside the source; there is no separate
// resource stub. The `.gen.odin` is named so the loader ignores it as an attachable script.
//
// Parsing is done PROPERLY with `core:odin/parser` + `core:odin/ast` (the struct,
// its fields/tags — including the typed signal fields — and the procs + their typed
// signatures). The `//gd:` comment markers (extends/class/tool/icon) — which Phases
// 1-3 already recognize — are scanned from the source text, exactly as the core's
// ResourceLoader does.
//
// Usage:
//   scriptgen <scripts_dir>
//     - emits <name>.gen.odin next to each script in <scripts_dir>
//   (a legacy `-res:<dir>` flag is accepted but ignored — stubs are no longer emitted.)
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:os"
import "core:strings"

// ---- Odin type -> Godot Variant mapping --------------------------------------

Variant_Kind :: enum {
	Int, // narrowable integers (i8..i64, uint, Int)
	Float, // f32 / f64
	Bool,
	Other, // engine-native width (String, Object, Vector2, ...)
	Nil, // void
}

Variant_Info :: struct {
	enum_name: string, // e.g. ".Int" — the gdext.Variant_Type member
	native:    string, // native Odin type behind the Variant (for signal-emit temps)
	kind:      Variant_Kind,
}

// Map a rendered Odin type string -> the Variant it presents as. `ok=false` means
// the type is unsupported (the caller emits a clear codegen error).
//
// Coverage is the FULL gdext.Variant_Type set: the scalar atoms (Bool/Int/Float, with
// width-narrowing via `size` for the .Int/.Float/.Bool kinds), every math struct
// (Vector*/Rect*/Transform*/Plane/Quaternion/Aabb/Basis/Projection/Color), the string
// family (String/String_Name/Node_Path), the misc handles (Rid/Object/Callable/Signal/
// Dictionary/Array) and all ten Packed_*_Array types. For these whole-struct/handle
// kinds the field IS the binding type, so `size = size_of(field)` and the core does no
// narrowing — it hands the field straight to the cached Variant<->type constructors.
map_variant :: proc(type_text: string) -> (Variant_Info, bool) {
	t := strings.trim_space(type_text)
	// Any pointer-to-object (`^gd.Node2d`, `^gd.Object`, ...) is a Variant Object.
	// A pointee qualified by an UNKNOWN import alias is not silently an Object though —
	// same rule as the non-pointer fallback below (ok=false; the caller errors).
	if strings.has_prefix(t, "^") {
		pointee := strings.trim_space(t[1:])
		if strings.contains(pointee, ".") &&
		   !strings.has_prefix(pointee, "gd.") && !strings.has_prefix(pointee, "godot.") {
			return {}, false
		}
		return Variant_Info{".Object", "rawptr", .Other}, true
	}
	// Typed collections — `Typed_Array(T)` / `Typed_Dictionary(K,V)` — resolve to plain Array /
	// Dictionary variants (the element types drive the EXPORT hint, derived separately). Checked
	// before the qualifier strip below, which would mangle a qualified element like `gd.String`.
	tq := t
	if strings.has_prefix(tq, "gd.") {
		tq = tq[3:]
	} else if strings.has_prefix(tq, "godot.") {
		tq = tq[6:]
	}
	if strings.has_prefix(tq, "Typed_Array(") {
		return Variant_Info{".Array", "gd.Array", .Other}, true
	}
	if strings.has_prefix(tq, "Typed_Dictionary(") {
		return Variant_Info{".Dictionary", "gd.Dictionary", .Other}, true
	}
	base := t
	if i := strings.last_index(base, "."); i >= 0 {
		// Only the KNOWN godot qualifier may be stripped. Author spellings are normalized
		// to `gd.` from the file's actual `godot:godot` import alias before they reach here
		// (normalize_godot_qualifier); `godot.` is additionally accepted for the marker
		// spellings that don't go through the AST. Any OTHER qualifier (a different import,
		// or a typo'd alias) is NOT silently a godot type — ok=false so the caller errors.
		if !strings.has_prefix(t, "gd.") && !strings.has_prefix(t, "godot.") {
			return {}, false
		}
		base = base[i + 1:] // strip the `gd.` / `godot.` qualifier
	}
	// A whole-struct/handle Variant: enum member ".X", native binding type "gd.X".
	other :: proc(name: string) -> (Variant_Info, bool) {
		return Variant_Info{strings.concatenate({".", name}), strings.concatenate({"gd.", name}), .Other}, true
	}
	switch base {
	// ---- scalar atoms (narrowed to the field's real width via `size`) ----
	case "int", "i64", "i32", "i16", "i8", "u64", "u32", "u16", "u8", "uint", "uintptr", "Int":
		return Variant_Info{".Int", "i64", .Int}, true
	case "f32", "f64", "Float", "Real":
		return Variant_Info{".Float", "f64", .Float}, true
	case "bool", "Bool":
		return Variant_Info{".Bool", "bool", .Bool}, true
	// ---- string family ----
	case "String", "string":
		return Variant_Info{".String", "gd.String", .Other}, true
	case "String_Name":
		return other("String_Name")
	case "Node_Path":
		return other("Node_Path")
	// ---- math structs ----
	case "Vector2":
		return other("Vector2")
	case "Vector2i":
		return other("Vector2i")
	case "Rect2":
		return other("Rect2")
	case "Rect2i":
		return other("Rect2i")
	case "Vector3":
		return other("Vector3")
	case "Vector3i":
		return other("Vector3i")
	case "Transform2d":
		return other("Transform2d")
	case "Vector4":
		return other("Vector4")
	case "Vector4i":
		return other("Vector4i")
	case "Plane":
		return other("Plane")
	case "Quaternion":
		return other("Quaternion")
	case "Aabb":
		return other("Aabb")
	case "Basis":
		return other("Basis")
	case "Transform3d":
		return other("Transform3d")
	case "Projection":
		return other("Projection")
	case "Color":
		return other("Color")
	// ---- misc handles ----
	case "Rid":
		return other("Rid")
	case "Object":
		return Variant_Info{".Object", "gd.Object", .Other}, true
	case "Callable":
		return other("Callable")
	case "Signal":
		return other("Signal")
	case "Dictionary":
		return other("Dictionary")
	case "Array":
		return other("Array")
	// ---- packed arrays ----
	case "Packed_Byte_Array":
		return other("Packed_Byte_Array")
	case "Packed_Int32_Array":
		return other("Packed_Int32_Array")
	case "Packed_Int64_Array":
		return other("Packed_Int64_Array")
	case "Packed_Float32_Array":
		return other("Packed_Float32_Array")
	case "Packed_Float64_Array":
		return other("Packed_Float64_Array")
	case "Packed_String_Array":
		return other("Packed_String_Array")
	case "Packed_Vector2_Array":
		return other("Packed_Vector2_Array")
	case "Packed_Vector3_Array":
		return other("Packed_Vector3_Array")
	case "Packed_Color_Array":
		return other("Packed_Color_Array")
	case "Packed_Vector4_Array":
		return other("Packed_Vector4_Array")
	case:
		// Any other QUALIFIED `gd.<Pascal>` selector is a godot Object/class handle
		// (Node2d, Sprite2D, Texture2D, ...) — these are all ObjectPtr aliases, so they
		// marshal as a Variant Object. Only the KNOWN godot qualifier gets this treatment
		// (unknown qualifiers already bailed above); an UNQUALIFIED or non-PascalCase token
		// (a typo, an `[N]T`, a `map`, ...) is NOT silently an Object — ok=false. A
		// PARAMETRIC spelling (contains '(', e.g. a `gd.Signal1(int)` marker used as a
		// method arg) is not a class handle either.
		if (strings.has_prefix(t, "gd.") || strings.has_prefix(t, "godot.")) &&
		   len(base) > 0 && base[0] >= 'A' && base[0] <= 'Z' &&
		   !strings.contains_rune(base, '(') {
			return Variant_Info{".Object", "rawptr", .Other}, true
		}
	}
	return {}, false
}

LIFECYCLE_KEYWORDS := [?]string{"physics_process", "process", "ready", "enter_tree", "exit_tree", "reload"}

// ---- parsed model ------------------------------------------------------------

// An @export field, reduced to what CODEGEN itself consumes. Hints/groups/defaults are
// no longer parsed here — the runtime reflection walk (runtime/register_class.odin)
// reads them from the same struct tag when the class registers. scriptgen keeps the
// field's Variant type (accessor-wrapper marshalling + the ctor set), the `get=`/`set=`
// proc names (wrapper emission), and the line/doc metadata reflection cannot see
// (published via the rt.Field_Meta table).
Export_Info :: struct {
	name:      string,
	type_text: string,
	vi:        Variant_Info,
	// richer-authoring #4: author proc names from `get=`/`set=` (""=plain field access).
	getter:    string,
	setter:    string,
	// 1-based source line of the field (for `_get_member_line` — editor jump-to-member).
	line:      int,
	// `///` doc comment above the field (property description for the editor doc panel).
	doc:       string,
}

// extract_doc joins the `///` lines of a doc comment group into a description string (leading
// `///` and one space stripped, lines joined with '\n'). Plain `//` comments are ignored, so
// documentation is opt-in via `///`. Returns "" when there's no `///` doc.
extract_doc :: proc(g: ^ast.Comment_Group) -> string {
	if g == nil {
		return ""
	}
	b := strings.builder_make()
	first := true
	for c in g.list {
		t := c.text
		if !strings.has_prefix(t, "///") {
			continue
		}
		line := strings.trim_space(t[3:])
		if !first {
			strings.write_byte(&b, '\n')
		}
		strings.write_string(&b, line)
		first = false
	}
	return strings.to_string(b)
}

Arg :: struct {
	name:      string,
	type_text: string,
	vi:        Variant_Info,
}

Method_Info :: struct {
	proc_name: string, // the user's Odin proc
	gd_name:   string, // the name exposed to GDScript
	args:      [dynamic]Arg,
	ret:       Variant_Info, // .Nil kind => void
	line:      int, // 1-based source line of the proc decl (duplicate-name diagnostics)
}

Lifecycle_Info :: struct {
	keyword:   string, // ready / process / physics_process / enter_tree / exit_tree
	proc_name: string,
	has_delta: bool,
	line:      int, // 1-based source line of the proc decl (duplicate diagnostics)
}

Signal_Arg :: struct {
	name: string,
	vi:   Variant_Info,
}

// A signal declared by a typed struct field (gd.Signal0 … Signal4, or gd.SignalN). The
// signal name IS the field name; `args` carries the payload (names from the `gd:"args=..."`
// tag / SignalN's payload-struct field names, else synthesized argN). Registration happens
// in the runtime reflection walk — scriptgen only consumes this for the typed
// `<snake>_emit_<name>` helper.
Signal_Info :: struct {
	name: string,
	args: [dynamic]Signal_Arg,
	line: int, // 1-based source line of the signal field (diagnostics)
}

// A `@(gd_connect="signal")` declaration on a method: auto-connect owner.signal -> method.
Connection_Info :: struct {
	signal: string, // the signal name on the owner node
	method: string, // the GDScript-exposed method name (the @(gd_method) gd_name)
}

// `MultiplayerAPI.RPCMode` int values (extension_api.json: MultiplayerAPI.RPCMode).
RPC_MODE_ANY_PEER :: 1
RPC_MODE_AUTHORITY :: 2

// `MultiplayerPeer.TransferMode` int values (extension_api.json: MultiplayerPeer.TransferMode).
TRANSFER_MODE_UNRELIABLE :: 0
TRANSFER_MODE_UNRELIABLE_ORDERED :: 1
TRANSFER_MODE_RELIABLE :: 2

// A `@(gd_rpc[="..."])` declaration on a `@(gd_method)` proc. `method` is the GDScript-exposed
// name; the rest is the resolved per-method RPC config the core hands the engine. Defaults
// mirror GDScript's bare `@rpc`: authority / reliable / no call_local / channel 0.
Rpc_Info :: struct {
	method:     string,
	mode:       int, // RPCMode int
	transfer:   int, // TransferMode int
	call_local: bool,
	channel:    int,
}

// A `gd:"replicate[,interp][,owner]"` field — a kit/net replicated field (friendslop
// toolkit). scriptgen records only name + options; the generated knet.Entity_Desc uses
// offset_of/size_of, and a generated #assert enforces the POD-only contract at the
// consumer's compile, naming the offending field.
Replicate_Info :: struct {
	field:  string,
	interp: bool, // remote peers interpolate this field
	owner:  bool, // part of the owner-authoritative unreliable stream
	lerp:   string, // knet.Lerp_Kind literal (".F32"/".F64") for interp fields; "" = Snap
}

// One @(gd_command) arg. Command args cross the wire, so the allowed types are
// kit/net's wire primitives — `wire` is the read_/write_ proc suffix and
// `type_text` the (knet.-normalized) spelling spliced into the wrapper signature.
Command_Arg :: struct {
	name:      string,
	type_text: string,
	wire:      string,
}

// One @(gd_command[="predict"]) proc — a host-authoritative action with optional
// client-side optimistic execution (friendslop toolkit, kit/net command loop).
Command_Info :: struct {
	proc_name: string, // author proc (chest_open) — also names the `<proc>_cmd` wrapper
	name:      string, // stripped verb (open) — knet.Command_Desc.name, diagnostics
	predict:   bool,
	args:      [dynamic]Command_Arg,
}

Script :: struct {
	path:        string, // source file path (diagnostics)
	godot_alias: string, // the file's `godot:godot` import alias ("" = not imported)
	pkg:         string,
	struct_name: string,
	class_name:  string,
	base:        string,
	doc:         string, // `///` doc comment above the script struct (class description)
	marked:      bool, // saw at least one valid `//gd:` marker (intent signal for diagnostics)
	tool:        bool,
	icon:        string, // `//gd:icon <res-path>` — custom class icon (""=none)
	exports:     [dynamic]Export_Info,
	lifecycles:  [dynamic]Lifecycle_Info,
	methods:     [dynamic]Method_Info,
	signals:     [dynamic]Signal_Info,
	connections: [dynamic]Connection_Info,
	rpcs:        [dynamic]Rpc_Info,
	replicates:  [dynamic]Replicate_Info,
	commands:    [dynamic]Command_Info,
	net_id_type: string, // type text of a `net_id` field ("" = none) — commands require knet.Net_Id
}

had_error: bool

// A diagnostic source location: `path:line:` when both are known, `path:` when only the
// file is known (line 0), or nothing (a global error). Marker scan line indexes count as
// lines (1-based), matching the AST's `pos.line`.
Loc :: struct {
	path: string,
	line: int,
}

// Print the diagnostic prefix. The `scriptgen: error:`/`scriptgen: warning:` convention is
// what build scripts grep for — the location slots in AFTER it (`scriptgen: error: path:line:`).
@(private = "file")
diag_prefix :: proc(kind: string, loc: Loc) {
	fmt.eprintf("scriptgen: %s: ", kind)
	if loc.path != "" {
		if loc.line > 0 {
			fmt.eprintf("%s:%d: ", loc.path, loc.line)
		} else {
			fmt.eprintf("%s: ", loc.path)
		}
	}
}

errorf :: proc(format: string, args: ..any) {
	error_at(Loc{}, format, ..args)
}

// Location-carrying error — prints `scriptgen: error: path:line: message`.
error_at :: proc(loc: Loc, format: string, args: ..any) {
	diag_prefix("error", loc)
	fmt.eprintf(format, ..args)
	fmt.eprintln()
	had_error = true
}

// Non-fatal diagnostic — prints but does NOT fail the build (used for likely-typo hints
// where scriptgen can't be sure, e.g. a proc whose name is one edit away from a lifecycle).
warnf :: proc(format: string, args: ..any) {
	warn_at(Loc{}, format, ..args)
}

warn_at :: proc(loc: Loc, format: string, args: ..any) {
	diag_prefix("warning", loc)
	fmt.eprintf(format, ..args)
	fmt.eprintln()
}

// ---- main --------------------------------------------------------------------

main :: proc() {
	args := os.args[1:]
	if len(args) < 1 {
		fmt.eprintln("usage: scriptgen <scripts_dir>")
		os.exit(2)
	}
	scripts_dir := ""
	for a in args {
		// `-res:<dir>` is a legacy flag from the two-file (stub) model — accepted but
		// ignored now that the authored source IS the attached resource.
		if strings.has_prefix(a, "-res:") {
			continue
		}
		scripts_dir = a
	}
	if scripts_dir == "" {
		fmt.eprintln("usage: scriptgen <scripts_dir>")
		os.exit(2)
	}
	// Canonicalize to ABSOLUTE before anything else touches the path. The owned-gen-file
	// set (below) is keyed by the ABSOLUTE `fullpath`s the directory listing reports, but
	// the boot-shim path used to be composed from this raw argument — with a RELATIVE
	// scripts dir the shim's key never matched, so orphan cleanup deleted the boot shim
	// it had JUST written. Making the one input path absolute fixes every derived path
	// (out_path already came from fullpath; boot_path now does too, in effect).
	if abs, aerr := os.get_absolute_path(scripts_dir, context.allocator); aerr == nil {
		scripts_dir = abs
	} else {
		fmt.eprintfln("scriptgen: cannot resolve dir %q", scripts_dir)
		os.exit(1)
	}

	// Structural whole-tree pass (helpers in subdirectories included) BEFORE the emit
	// loop: module-isolation import checks are hard errors even in files the emit loop
	// never parses, and a marked script hiding in a subdirectory gets a warning instead
	// of silently never becoming attachable. See check_tree.
	check_tree(scripts_dir)

	dir_fh, oerr := os.open(scripts_dir)
	if oerr != nil {
		fmt.eprintfln("scriptgen: cannot open dir %q", scripts_dir)
		os.exit(1)
	}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {
		fmt.eprintfln("scriptgen: cannot read dir %q", scripts_dir)
		os.exit(1)
	}

	emitted := 0
	pkg := "" // the scripts package name (for the generated boot); from the first source file
	has_boot := false // a hand-written `odin_scripts_boot` exists — don't generate one
	seen_classes := make(map[string]string) // //gd:class name -> file that declared it
	defer delete(seen_classes)
	// Every gen file THIS run owns (wrote, or would have written but for an unrelated
	// earlier error): the `<src>.gen.odin` per emitted script plus the boot shim. Anything
	// else matching `*.gen.odin` in the dir is a stale orphan (its source was deleted or
	// renamed) and is removed after the emit loop — a stale gen file otherwise breaks the
	// build inside "DO NOT EDIT" code.
	owned_gen := make(map[string]bool)
	defer delete(owned_gen)
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		path := fi.fullpath

		src_bytes, rerr := os.read_entire_file_from_path(path, context.allocator)
		if rerr != nil {
			errorf("cannot read %q", path)
			continue
		}
		src := string(src_bytes)

		// Track the package name + whether the project already supplies its own boot. We
		// scan EVERY source file (not just scripts) so a hand-written boot.odin — which has
		// no owner-struct and so isn't a "script" — is still detected and respected.
		if pkg == "" {
			if p := scan_package(src); p != "" {pkg = p}
		}
		// A DECLARATION of `odin_scripts_boot` (not a mere mention in a comment/string —
		// that used to suppress boot generation and break the dll's init handshake).
		if scan_boot_decl(src) {has_boot = true}

		script, has := parse_script(path, src)
		if !has {continue} // not a script file (no owner-struct) — skip silently

		// Duplicate //gd:class across files: the core's name->desc map would silently let the
		// last-loaded win and mis-bind the other. Catch it here with both file paths. This
		// bookkeeping runs BEFORE the had_error skip below so dup detection keeps working
		// across the remaining files even after an unrelated error.
		if prev, dup := seen_classes[script.class_name]; dup {
			error_at(Loc{path = path}, "duplicate //gd:class %q (also declared in %q)", script.class_name, prev)
		} else {
			seen_classes[script.class_name] = path
		}

		// This script's gen file is ours either way — never orphan-collect it.
		out_path := strings.concatenate({path[:len(path) - len(".odin")], ".gen.odin"})
		owned_gen[norm_path(out_path)] = true

		if had_error {continue}
		gen := generate(&script)
		if werr := os.write_entire_file(out_path, transmute([]byte)gen); werr != nil {
			errorf("cannot write %q", out_path)
			continue
		}
		fmt.printfln("scriptgen: wrote %s", out_path)
		emitted += 1
	}

	// Generate the REQUIRED boot shim (the `odin_scripts_boot` export the core calls after
	// dlopen) so users never hand-copy it — UNLESS the project already defines its own.
	// Skipped when the package has no name (nothing to compile anyway).
	if !had_error && !has_boot && pkg != "" {
		dir := strings.trim_suffix(strings.trim_suffix(scripts_dir, "/"), "\\")
		boot_path := strings.concatenate({dir, "/odin_godot_boot.gen.odin"})
		owned_gen[norm_path(boot_path)] = true
		if werr := os.write_entire_file(boot_path, transmute([]byte)gen_boot(pkg)); werr != nil {
			errorf("cannot write %q", boot_path)
		} else {
			fmt.printfln("scriptgen: wrote %s (boot shim)", boot_path)
		}
	}

	if had_error {
		os.exit(1)
	}

	// Orphan cleanup: delete any `*.gen.odin` in the scripts dir that this run does not own
	// (its authored source was deleted/renamed, or a hand-written boot replaced the shim).
	// Only on a CLEAN run — after an error nothing was emitted, so nothing is collected.
	// The dir is re-listed because the emit loop just changed its contents. Scripts live
	// flat in the one dir (the emit loop above skips subdirectories), so no recursion.
	remove_orphan_gen(scripts_dir, owned_gen)

	fmt.printfln("scriptgen: generated %d script(s)", emitted)
}

// norm_path returns `p` with backslashes normalized to '/'. The owned-gen map is keyed by
// NORMALIZED absolute paths so a `\`-separated fullpath from the Windows directory listing
// still matches a `dir + "/leaf"` composed path (the boot shim) — the same key-mismatch
// class that made a RELATIVE scripts-dir argument orphan-collect the just-written boot
// shim before main() canonicalized the argument. No-op (no allocation) on POSIX paths.
norm_path :: proc(p: string, allocator := context.allocator) -> string {
	if !strings.contains_rune(p, '\\') {return p}
	out, _ := strings.replace_all(p, "\\", "/", allocator)
	return out
}

// remove_orphan_gen deletes `*.gen.odin` files under `dir` that are not in `owned` —
// gen output for sources that no longer exist. A Godot `.uid` sidecar for a removed gen
// file goes with it (the editor generates those beside every res:// file).
remove_orphan_gen :: proc(dir: string, owned: map[string]bool) {
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return}
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".gen.odin") {continue}
		if owned[norm_path(fi.fullpath, context.temp_allocator)] {continue}
		if rmerr := os.remove(fi.fullpath); rmerr != nil {
			// Non-fatal: warn — the stale file will still break the scripts build with a
			// clear-enough odin error, and the next run retries.
			warn_at(Loc{path = fi.fullpath}, "cannot remove stale gen file")
			continue
		}
		fmt.printfln("scriptgen: removed stale %s (no matching source)", fi.fullpath)
		uid := strings.concatenate({fi.fullpath, ".uid"})
		if os.exists(uid) {
			os.remove(uid)
		}
	}
}

// ---------------------------------------------------------------------------
// Whole-tree structural checks (module isolation + misplaced //gd: markers)
// ---------------------------------------------------------------------------

// check_tree — one recursive pass over EVERY authored `.odin` under the scripts dir
// (the emit loop above only parses TOP-LEVEL files; subdirectories are helper packages):
//
//   1. IMPORT ISOLATION, all files: a script module may import collections
//      (godot:/core:/base:/vendor:) and packages that RESOLVE INSIDE the module's own
//      directory (subdir helpers, helpers importing each other). Anything else — an
//      absolute path, or a relative path that escapes the module root after lexical
//      normalization — is a HARD ERROR. Odin itself would happily compile
//      `import "../other_module"`, but a package linked into two script dlls duplicates
//      its package GLOBALS per dll and the "shared" state silently forks. The bash/ps1
//      builds keep a fast grep for the same rule (check_module_isolation in
//      build/common.sh, ported in build/build_scripts.ps1) as a backstop; THIS is the
//      structural check that also catches absolute paths and creative spellings.
//
//   2. MISPLACED MARKERS, subdirectory files only: a `//gd:` header marker on a file in
//      a subdirectory is a script that will never be attachable (no gen is emitted for
//      subdirs) — warn, don't error, since the file still compiles as helper code.
check_tree :: proc(scripts_dir: string) {
	check_tree_dir(scripts_dir, scripts_dir, true)
}

check_tree_dir :: proc(dir, root: string, is_top: bool) {
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return} // unreadable dirs are surfaced by the emit loop / odin build
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return}
	for fi in files {
		if fi.type == .Directory {
			if strings.has_prefix(fi.name, ".") {continue} // .godot and friends
			check_tree_dir(fi.fullpath, root, false)
			continue
		}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		check_file(fi.fullpath, root, is_top)
	}
}

// Parser diagnostics stay SILENT here: a file that doesn't parse is reported properly by
// the emit loop (top level) or by `odin build` itself — this pass must not double-print.
@(private = "file")
silent_parse_diag :: proc(pos: tokenizer.Pos, format: string, args: ..any) {}

check_file :: proc(path, root: string, is_top: bool) {
	src_bytes, rerr := os.read_entire_file_from_path(path, context.allocator)
	if rerr != nil {return}
	src := string(src_bytes)
	file := ast.File {
		fullpath = path,
		src      = src,
	}
	p := parser.default_parser()
	p.err = silent_parse_diag
	p.warn = silent_parse_diag
	if !parser.parse_file(&p, &file) {return} // unparseable — odin build reports it
	file_dir := norm_path(path)
	if i := strings.last_index(file_dir, "/"); i >= 0 {
		file_dir = file_dir[:i]
	}
	for imp in file.imports {
		check_import(root, file_dir, path, imp)
	}
	if !is_top {
		warn_subdir_markers(path, src, file.pkg_token.pos.line)
	}
}

// The teaching text shared with the bash grep (check_module_isolation in build/common.sh)
// — why a cross-module import is rejected instead of merely discouraged.
@(private = "file")
explain_isolation :: proc() {
	fmt.eprintln("  Script modules are ISOLATED packages: a package imported by two script dlls")
	fmt.eprintln("  duplicates its globals per dll (shared state would silently fork). Talk to")
	fmt.eprintln("  other modules through the engine (signals / methods / autoloads) instead,")
	fmt.eprintln("  or move the shared state into exactly one module.")
}

// check_import validates ONE import declaration against the isolation rule. `root` is the
// absolute scripts dir being compiled; `file_dir` the importing file's dir (normalized).
check_import :: proc(root, file_dir, path: string, imp: ^ast.Import_Decl) {
	ipath := strings.trim(imp.fullpath, "\"")
	loc := Loc{path, imp.pos.line}
	// `<collection>:<pkg>` — godot:/core:/base:/vendor: (an unknown collection is odin
	// build's own error). Collection imports never cross module boundaries.
	if strings.contains_rune(ipath, ':') {return}
	if strings.has_prefix(ipath, "/") || strings.has_prefix(ipath, "\\") {
		error_at(loc, "ILLEGAL cross-module import %q — absolute import paths are not allowed in a script module; import collections (godot:/core:/base:/vendor:) or packages inside this module's directory", ipath)
		explain_isolation()
		return
	}
	nroot := norm_path(root)
	resolved := resolve_lexical(file_dir, ipath)
	if resolved != nroot && !strings.has_prefix(resolved, strings.concatenate({nroot, "/"})) {
		error_at(loc, "ILLEGAL cross-module import %q — resolves to %q, outside this script module's directory (%s)", ipath, resolved, nroot)
		explain_isolation()
	}
}

// resolve_lexical joins `rel` onto `base_dir` and normalizes `.`/`..` segments purely
// lexically (no filesystem access — symlink dodges are not a concern here, the rule is
// about what the COMPILER will resolve, and odin resolves imports lexically too).
resolve_lexical :: proc(base_dir, rel: string) -> string {
	joined := strings.concatenate({norm_path(base_dir), "/", norm_path(rel)}, context.temp_allocator)
	parts := strings.split(joined, "/", context.temp_allocator)
	stack := make([dynamic]string, context.temp_allocator)
	for part in parts {
		switch part {
		case "", ".":
		case "..":
			if len(stack) > 0 {pop(&stack)}
		case:
			append(&stack, part)
		}
	}
	b := strings.builder_make()
	lead := strings.has_prefix(joined, "/") // POSIX abs; a Windows `C:/...` keeps its drive segment
	for part, i in stack {
		if i > 0 || lead {strings.write_byte(&b, '/')}
		strings.write_string(&b, part)
	}
	return strings.to_string(b)
}

// warn_subdir_markers — the misplaced-marker warning (check_tree case 2). Header region
// only (lines BEFORE the package decl), matching scan_markers' convention; only the four
// real markers warn — an unknown `//gd:` line in a helper is not a claim of script-ness.
warn_subdir_markers :: proc(path, src: string, pkg_line: int) {
	it := src
	ln := 0
	for line in strings.split_lines_iterator(&it) {
		ln += 1
		if pkg_line > 0 && ln >= pkg_line {break}
		l := strings.trim_space(line)
		if !strings.has_prefix(l, "//gd:") {continue}
		body := strings.trim_space(l[len("//gd:"):])
		for kw in ([4]string{"extends", "class", "tool", "icon"}) {
			if _, ok := marker_arg(body, kw); ok {
				warn_at(
					Loc{path, ln},
					"//gd:%s in a subdirectory file — attachable scripts must live at the top level of the scripts dir; subdirectories are helper packages",
					kw,
				)
				break
			}
		}
	}
}

// scan_boot_decl reports whether the source DECLARES `odin_scripts_boot` (a line whose
// trimmed form is `odin_scripts_boot ::` ...). A mention inside a comment or string —
// e.g. docs referencing the boot shim — must NOT suppress boot generation.
scan_boot_decl :: proc(src: string) -> bool {
	it := src
	for line in strings.split_lines_iterator(&it) {
		t := strings.trim_space(line)
		if !strings.has_prefix(t, "odin_scripts_boot") {continue}
		rest := strings.trim_space(t[len("odin_scripts_boot"):])
		if strings.has_prefix(rest, "::") {return true}
	}
	return false
}

// First `package <name>` declaration in a source file (cheap line scan — independent of the
// full parser so it works on any .odin, including non-script helpers).
scan_package :: proc(src: string) -> string {
	it := src
	for line in strings.split_lines_iterator(&it) {
		t := strings.trim_space(line)
		if !strings.has_prefix(t, "package ") {continue}
		rest := strings.trim_space(t[len("package "):])
		// Cut at the first whitespace or line comment.
		end := len(rest)
		for r, i in rest {
			if r == ' ' || r == '\t' || (r == '/' && i + 1 < len(rest) && rest[i + 1] == '/') {
				end = i
				break
			}
		}
		return strings.trim_space(rest[:end])
	}
	return ""
}

// The generated boot shim: the `@(export) odin_scripts_boot` the core invokes right after
// it dlopens the scripts dll, so the dll initializes its OWN gdext/godot package globals
// before any script proc runs. (Define your own `odin_scripts_boot` to opt out.)
gen_boot :: proc(pkg: string) -> string {
	b: strings.Builder
	strings.builder_init(&b)
	// NATIVE-ONLY: on web all script packages link into ONE side module (no dlopen — the
	// core's own init runs instead), so the boot export is dead code there; and with the
	// multi-module layout, several packages each exporting `odin_scripts_boot` would be a
	// duplicate-symbol link error in that single wasm module.
	fmt.sbprintf(&b, "#+build darwin, linux, windows\npackage %s\n\n", pkg)
	w :: strings.write_string
	w(&b, "// GENERATED by scriptgen — do not edit. The odin_godot CORE dll calls\n")
	w(&b, "// `odin_scripts_boot` immediately after it dlopens this compiled scripts dll, so the\n")
	w(&b, "// dll can initialize its OWN gdext/godot package globals before any of your script\n")
	w(&b, "// procs run. Define your own `odin_scripts_boot` in a hand-written file to opt out.\n\n")
	w(&b, "import \"godot:gdext\"\n")
	w(&b, "import \"godot:godot\"\n\n")
	w(&b, "@(export)\n")
	w(&b, "odin_scripts_boot :: proc \"c\" (\n")
	w(&b, "\tget_proc_address: gdext.ExtensionInterfaceGetProcAddress,\n")
	w(&b, "\tlibrary: gdext.ExtensionClassLibraryPtr,\n")
	w(&b, ") {\n")
	w(&b, "\tgdext.init(library, get_proc_address)\n")
	w(&b, "\tgodot.init()\n")
	w(&b, "}\n")
	return strings.to_string(b)
}
