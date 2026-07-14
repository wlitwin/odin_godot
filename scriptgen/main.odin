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
	gd_name:   string, // the name exposed to GDScript (namespaced for a composed block method)
	args:      [dynamic]Arg,
	ret:       Variant_Info, // .Nil kind => void
	line:      int, // 1-based source line of the proc decl (duplicate-name diagnostics)
	// Method-composition (the engine-facing dual of verb-composition): a @(gd_method)/@(gd_rpc)
	// whose receiver is an EMBEDDED sub-struct is hoisted onto the entity's method table, routed
	// into &self.<path>. Mirrors Command_Info: nil path = a direct method (routes to `self`);
	// `owner` = a pointer param after the receiver (scriptgen passes `self`); pkg_* qualify + import
	// the sub-proc's package. is_rpc/rpc/connect are captured for an INDEXED block method and
	// re-emitted with the namespaced gd_name at hoist (a direct method's rpc/connect go straight to
	// s.rpcs/s.connections in scan_bound_procs, so these stay zero there).
	path:      []string,
	owner:     bool,
	pkg_alias: string,
	pkg_path:  string,
	is_rpc:    bool,
	rpc:       Rpc_Info,
	connect:   string, // @(gd_connect) signal on the block method, "" = none
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
	field:  string, // leaf field name (diagnostics/display)
	// Access segments from the entity-struct root to this field, e.g. {"hp"} for a
	// top-level field, {"move","x"} for a field reached through a `using`/embedded
	// sub-struct. generate.odin turns this into the offset/size/POD expressions
	// (nested-replicate-fields KB doc). Always at least length 1.
	path:   []string,
	interp: bool, // remote peers interpolate this field
	owner:  bool, // part of the owner-authoritative unreliable stream
	predict: bool, // kit/sim lane: server-sim-authoritative, client-predicted + reconciled
	lerp:   string, // knet.Lerp_Kind literal (".F32"/".F64"/".Quat"/".Custom"); "" = Snap
	blend:  string, // `interp=NAME`: the author's knet.Blend_Proc, spliced verbatim
	wire:   string, // knet.Wire_Kind literal (".F16"/".Custom"); "" = raw struct bytes
	codec:  string, // `wire=NAME`: the author's knet.Wire_Codec, spliced verbatim
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
	proc_name: string, // author proc (chest_open / gun_fire) — names the decode thunk (+ a direct command's wrapper)
	name:      string, // entity-level command name: a direct command's stripped verb ("open"), or a
	                   // COMPOSED one's "<path>_<verb>" ("gun_fire") — drives the index const + wrapper
	predict:   bool,
	args:      [dynamic]Command_Arg,
	// Verb-composition: a command whose proc lives on an EMBEDDED sub-struct field is hoisted
	// onto the entity (the dual of a nested `gd:"replicate"` field). `path` is the access path
	// from the entity root to that field ({"gun"} or {"loadout","primary"}); nil/empty = a
	// DIRECT command on the entity (the decode thunk routes to `self`). `owner` = the sub-proc
	// takes a `^Entity` param right after its receiver — a pointer, so never a wire arg —
	// which scriptgen fills with `self` so the block can read/write its wielder. pkg_alias /
	// pkg_path qualify + import the sub-proc's package into the generated file ("" = the
	// entity's own package: no qualifier, no import).
	path:      []string,
	owner:     bool,
	pkg_alias: string,
	pkg_path:  string,
	// Consequence pairing (`<wrapper>_then`): a verb may return `(bool, payload…)`
	// and the game may declare a name-paired consequence proc — the typed,
	// authority-only "and then…" that replaces scratch fields + the untyped hook
	// switch. `payload_count` is how many results ride behind the applied bool
	// (they never cross the wire — the consequence runs in the same process as
	// the authoritative verb). `then_proc` = "" means no consequence declared;
	// `then_game` is the leading game param's pointee ("Scrapyard", "" = the
	// entity-local form) — generated code casts ctx.game_user/env.user to it.
	payload_count: int,
	then_proc:     string,
	then_game:     string,
}

// An `entity=Name:id` declaration on an exported PackedScene field — one row
// of the kboot entity table (factory consolidation): the scene stays an
// editor-wired export; the tag names the entity struct it bodies and its
// STABLE wire id (explicit on purpose — auto-numbering would silently
// renumber saves/rejoins/backups on any edit).
Entity_Tag :: struct {
	field:   string, // the scene field (offset_of target on the game struct)
	target:  string, // the entity struct the scene bodies ("Mob")
	type_id: int,    // the stable ksess.Entity_Type value
	line:    int,
	// Resolved by resolve_entities (module-wide): the optional name-paired
	// typed hooks ("" = not declared).
	spawned: string, // <target_snake>_spawned
	freed:   string, // <target_snake>_freed
	has_tick: bool, // the target declares @(gd_tick) — the kinds row carries its Sim_Set
}

// The one @(gd_tick) proc a class may declare — its sim-lane step (kit/sim).
// scriptgen generates the rawptr thunk and the `<snake>_sim_set` the game
// hands to ksim.lane_track_set.
Tick_Info :: struct {
	proc_name:     string,
	input_type:    string, // the input param's type text, spliced verbatim ("" = inputless)
	wants_lane:    bool, // trailing `lane: ^ksim.Lane` param — threaded by the thunk
	line:          int,
	contested:     bool, // @(gd_tick="contested"): every peer predicts this entity
	payload_count: int, // results = FACTS the tick learned (fired, dashed, landed) —
	                    // threaded to the name-paired halves below, never wire'd
	then_proc:     string, // `<proc>_then`: AUTHORITY-only consequence ("" = none)
	then_game:     string, // its optional leading game param type ("" = self-first shape)
	fx_proc:       string, // `<proc>_fx`: owning peer's LIVE-pass presentation ("" = none)
	fx_game:       string,
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
	entities:    [dynamic]Entity_Tag, // entity=Name:id scene fields (the kboot table)
	net_id_type: string, // type text of a `net_id` field ("" = none) — commands require knet.Net_Id
	tick:        Tick_Info, // proc_name == "" = the class doesn't tick
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

// ---- struct index + cross-package resolver (nested-replicate-fields) ----------
//
// So a `gd:"replicate"` (or, through `using`, export/onready/signal) field reached
// through an embedded sub-struct is discovered, the parser must resolve the sub-struct's
// DEFINITION. Same-package types live in a sibling file; IMPORTED bundles (`using cs:
// kcombat.State`) live in another package under the `godot:` collection. The index maps
// each package DIR to its `Name :: struct {...}` defs; imported packages are parsed on
// demand. Resolution is per-def: bare `Name` resolves in the def's own package, and
// `alias.Name` resolves through the def's file imports into another package. See the
// nested-replicate-fields KB doc.

Struct_Field :: struct {
	name:      string,
	type_text: string, // rendered + gd.-normalized (ready for map_variant/POD checks)
	tag:       string, // raw struct-tag text (may be "")
	is_using:  bool,
	loc:       Loc, // where this field is declared (for nested-field diagnostics)
}

Struct_Def :: struct {
	id:          string, // "<dir>|<name>" — stable identity for cycle detection
	dir:         string, // the package dir this struct lives in (bare-name resolution)
	fields:      []Struct_Field,
	imports:     map[string]string, // defining file's EXPLICIT-alias imports (alias -> "godot:kit/combat")
	poly_params: []string, // generic parameter names ("$S" stripped to "S"), in order; nil = not generic
	// @(gd_command) procs whose FIRST param is `^<this struct>` (verb-composition), and
	// @(gd_method)/@(gd_rpc) procs likewise (method-composition). An entity that embeds this struct
	// hoists these onto its own command / method tables (recurse_into). Collected on demand by
	// index_pkg_dir alongside the fields. nil for a struct with none.
	commands:    []Command_Info,
	methods:     []Method_Info,
}

// dir -> (bare struct name -> def). The scripts package, plus any imported packages
// pulled in on demand for nested-bundle resolution.
g_pkgs: map[string]map[string]Struct_Def
g_pkg_loaded: map[string]bool // dirs already parsed (incl. unreadable, so we never retry)
g_godot_root: string // the `godot:` collection root (-godot: flag / ODIN_GODOT_ROOT); "" disables imported bundles

// Parse every .odin in `dir` (idempotent) and record its struct decls. Parser diagnostics
// stay silent — the emit loop / `odin build` report parse errors properly.
index_pkg_dir :: proc(dir: string) {
	if g_pkg_loaded[dir] {return}
	g_pkg_loaded[dir] = true
	// Populate `pkg` fully, then publish it on EVERY exit path. (An Odin map value is a
	// header copied by value — inserting into a local after storing it would leave the
	// stored copy stale once the backing grows; so we store the final header via defer.)
	pkg := make(map[string]Struct_Def)
	defer g_pkgs[dir] = pkg
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return}
	// alias (the godot:godot import) is per-file; commands index ACROSS files (a struct and its
	// commands may live apart), so the receiver-keyed map lives at dir scope and is attached to
	// the defs once every file is in.
	cmds := make(map[string][dynamic]Command_Info)
	meths := make(map[string][dynamic]Method_Info)
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		src_bytes, rerr := os.read_entire_file_from_path(fi.fullpath, context.allocator)
		if rerr != nil {continue}
		src := string(src_bytes)
		file := ast.File {
			fullpath = fi.fullpath,
			src      = src,
		}
		p := parser.default_parser()
		p.err = silent_parse_diag
		p.warn = silent_parse_diag
		if !parser.parse_file(&p, &file) {continue}
		alias := godot_import_alias(&file)
		imports := collect_file_imports(&file)
		for decl in file.decls {
			vd, ok := decl.derived.(^ast.Value_Decl)
			if !ok {continue}
			if len(vd.names) != 1 || len(vd.values) != 1 {continue}
			if st, is_struct := vd.values[0].derived.(^ast.Struct_Type); is_struct && st.fields != nil {
				name_ident, _ := vd.names[0].derived.(^ast.Ident)
				if name_ident == nil {continue}
				pkg[name_ident.name] = build_struct_def(dir, fi.fullpath, name_ident.name, st, src, alias, imports)
				continue
			}
			// verb-/method-composition: a bound proc on a struct in THIS package (first param
			// `^Name`, or `^Name($S)` for a generic block) — index it under that struct so an
			// embedding entity can hoist it. Same receiver rule scan_bound_procs uses for entities;
			// build_* report contract violations loudly, so a block's verbs/methods are validated
			// when a game first imports the package.
			pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
			if !is_proc {continue}
			pt := pl.type
			if pt == nil || pt.params == nil || len(pt.params.list) == 0 {continue}
			recv := strings.trim_space(node_text(src, pt.params.list[0].type))
			if !strings.has_prefix(recv, "^") {continue}
			base := strings.trim_space(recv[1:])
			if paren := strings.index_byte(base, '('); paren >= 0 {base = strings.trim_space(base[:paren])}
			name_ident, _ := vd.names[0].derived.(^ast.Ident)
			if name_ident == nil {continue}
			loc := Loc{fi.fullpath, name_ident.pos.line}
			if has_attr(vd, "gd_command") {
				config, _ := attr_value(vd, "gd_command")
				if ci, cok := build_command_info(src, pt, loc, name_ident.name, base, config, true); cok {
					arr := cmds[base]
					append(&arr, ci)
					cmds[base] = arr
				}
				continue
			}
			is_rpc := has_attr(vd, "gd_rpc")
			if has_attr(vd, "gd_method") || is_rpc {
				if mi, mok := build_method_info(src, pt, loc, name_ident.name, base, true); mok {
					if is_rpc {
						mi.is_rpc = true
						rconfig, _ := attr_value(vd, "gd_rpc")
						mi.rpc = parse_rpc_config(mi.gd_name, rconfig)
					}
					if sig, has := attr_value(vd, "gd_connect"); has {mi.connect = sig}
					arr := meths[base]
					append(&arr, mi)
					meths[base] = arr
				}
			}
		}
	}
	// Attach each struct's commands + methods (gathered across every file in the dir) to its def.
	for name, arr in cmds {
		if def, dok := pkg[name]; dok {
			def.commands = arr[:]
			pkg[name] = def
		}
	}
	for name, arr in meths {
		if def, dok := pkg[name]; dok {
			def.methods = arr[:]
			pkg[name] = def
		}
	}
}

@(private = "file")
build_struct_def :: proc(dir, path, name: string, st: ^ast.Struct_Type, src, alias: string, imports: map[string]string) -> Struct_Def {
	fields := make([dynamic]Struct_Field)
	for f in st.fields.list {
		type_text := normalize_godot_qualifier(node_text(src, f.type), alias)
		is_using := .Using in f.flags
		tag := f.tag.text
		for nm in f.names {
			ident, ok := nm.derived.(^ast.Ident)
			if !ok || ident == nil {continue}
			append(
				&fields,
				Struct_Field {
					name = ident.name,
					type_text = type_text,
					tag = tag,
					is_using = is_using,
					loc = Loc{path, ident.pos.line},
				},
			)
		}
	}
	// Generic parameters (`struct($S: typeid, $N: int)`): record the names ("$S" -> "S")
	// in order, so an instantiation `Machine(Gun_State)` can be zipped param->arg and the
	// substitution applied to member types (nested-replicate-fields generics).
	poly: [dynamic]string
	if st.poly_params != nil {
		for pf in st.poly_params.list {
			for nm in pf.names {
				pn := strings.trim_prefix(strings.trim_space(node_text(src, nm)), "$")
				if pn != "" {append(&poly, pn)}
			}
		}
	}

	return Struct_Def {
		id = strings.concatenate({dir, "|", name}),
		dir = dir,
		fields = fields[:],
		imports = imports,
		poly_params = poly[:],
	}
}

// dir -> the `package` name its files declare ("" = none found). Lazy cache for
// bare-import resolution below — deliberately independent of index_pkg_dir, so a
// name lookup never recurses into (or waits on) full struct indexing.
g_pkg_names: map[string]string

// The package NAME a directory's files declare — parse authored .odin files until
// one yields it. Misses are cached too, so an unreadable dir asks the disk once.
package_name_of :: proc(dir: string) -> string {
	if name, ok := g_pkg_names[dir]; ok {return name}
	g_pkg_names[dir] = "" // publish the miss first; overwrite on success
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return ""}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return ""}
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		src_bytes, rerr := os.read_entire_file_from_path(fi.fullpath, context.allocator)
		if rerr != nil {continue}
		file := ast.File {
			fullpath = fi.fullpath,
			src      = string(src_bytes),
		}
		p := parser.default_parser()
		p.err = silent_parse_diag
		p.warn = silent_parse_diag
		if !parser.parse_file(&p, &file) {continue}
		if file.pkg_name != "" {
			g_pkg_names[dir] = file.pkg_name
			return file.pkg_name
		}
	}
	return ""
}

// alias -> import fullpath. Explicit aliases map directly (`import k "godot:kit/net"`).
// A BARE import binds the target's package NAME — resolved by reading the imported
// dir's package clause (package_name_of, cached) — so `import "godot:play"` composes
// exactly like the aliased form. (It used to be alias-only: a bare import silently
// skipped the embed's fields and verbs, which cost a real debugging session — the
// gun compiled, ran, and just never replicated.) Only the godot: collection resolves;
// other collections stay engine/core leaves. godot:godot is excluded (engine types);
// `_` imports are side-effect only.
collect_file_imports :: proc(file: ^ast.File) -> map[string]string {
	m := make(map[string]string)
	for imp in file.imports {
		if imp.name.text == "_" {continue}
		full := strings.trim(imp.fullpath, "\"")
		if full == "godot:godot" {continue}
		name := imp.name.text
		if name == "" {
			dir, dok := resolve_import_dir(full)
			if !dok {continue}
			name = package_name_of(dir)
			if name == "" {continue}
		}
		m[name] = full
	}
	return m
}

// "godot:kit/combat" -> "<root>/kit/combat". Only the godot: collection resolves; other
// collections (core:/base:/vendor:) and relative imports are not bundle sources here.
resolve_import_dir :: proc(imp: string) -> (string, bool) {
	colon := strings.index_byte(imp, ':')
	if colon < 0 {return "", false}
	if imp[:colon] != "godot" || g_godot_root == "" {return "", false}
	rel := imp[colon + 1:]
	return strings.concatenate({g_godot_root, "/", rel}), true
}

// Resolve a field's type text (seen inside `from`) to a struct def. Bare `Name` resolves
// in `from`'s own package; `alias.Name` resolves through `from`'s imports into another
// package (parsed on demand). ok=false for builtins, decorated types ([N]T / ^T /
// parametric), engine (gd.) types, unresolved imports, or a name that isn't an indexed struct.
lookup_struct :: proc(from: Struct_Def, type_text: string) -> (Struct_Def, bool) {
	t := strings.trim_space(type_text)
	if len(t) == 0 || t[0] == '^' || strings.contains(t, "[") || strings.contains(t, "(") {
		return {}, false
	}
	if dot := strings.index_byte(t, '.'); dot >= 0 {
		alias := t[:dot]
		name := t[dot + 1:]
		if alias == "gd" || alias == "godot" {return {}, false}
		imp, has := from.imports[alias]
		if !has {return {}, false}
		dir, dok := resolve_import_dir(imp)
		if !dok {return {}, false}
		index_pkg_dir(dir) // lazy parse (idempotent)
		if pkg, pok := g_pkgs[dir]; pok {
			if def, sok := pkg[name]; sok {return def, true}
		}
		return {}, false
	}
	if pkg, pok := g_pkgs[from.dir]; pok {
		if def, sok := pkg[t]; sok {return def, true}
	}
	return {}, false
}

// resolve_type resolves a field's type text (seen inside `from`, and already substituted
// for any outer generic params) to a struct def, plus a substitution map for its OWN
// generic parameters. A generic instantiation `Machine(Gun_State)` resolves the base
// `Machine` and zips its params to the args (`{S = "Gun_State"}`); a plain name resolves
// via lookup_struct with an empty substitution. ok=false for non-structs / pointers /
// arrays / unresolved names — the caller skips recursion (nested-replicate-fields generics).
resolve_type :: proc(from: Struct_Def, type_text: string) -> (Struct_Def, map[string]string, bool) {
	t := strings.trim_space(type_text)
	if len(t) == 0 || t[0] == '^' || strings.has_prefix(t, "[") {
		return {}, nil, false
	}
	if paren := strings.index_byte(t, '('); paren >= 0 {
		if !strings.has_suffix(t, ")") {return {}, nil, false}
		base := strings.trim_space(t[:paren])
		def, ok := lookup_struct(from, base)
		if !ok {return {}, nil, false}
		args := split_type_params(t[paren + 1:len(t) - 1]) // top-level comma split (parse.odin)
		defer delete(args)
		subst := make(map[string]string)
		for p, i in def.poly_params {
			if i < len(args) {subst[p] = strings.trim_space(args[i])}
		}
		return def, subst, true
	}
	def, ok := lookup_struct(from, t)
	return def, nil, ok
}

// The directory containing a file path (normalized, no trailing slash).
dir_of :: proc(path: string) -> string {
	p := norm_path(path)
	if i := strings.last_index(p, "/"); i >= 0 {
		return p[:i]
	}
	return p
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
		// `-godot:<path>` — the `godot:` collection root, so nested `using` bundles
		// imported from `godot:kit/*` can be resolved (nested-replicate-fields Phase 2).
		if strings.has_prefix(a, "-godot:") {
			g_godot_root = a[len("-godot:"):]
			continue
		}
		scripts_dir = a
	}
	// Fallback to the env every test/build already exports; "" leaves imported bundles
	// unresolved (same as same-package-only), never a silent wrong result.
	if g_godot_root == "" {
		g_godot_root = os.get_env("ODIN_GODOT_ROOT", context.allocator)
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

	// Index the scripts package BEFORE parsing scripts, so parse_script can resolve
	// nested `using`/embedded sub-structs to scan them for gd tags. Imported bundle
	// packages are pulled in on demand during resolution (nested-replicate-fields).
	index_pkg_dir(norm_path(scripts_dir))

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

	// Pass 1: parse every top-level file. Script files (owner-struct) become pending
	// gen output; the rest are HELPERS, remembered for pass 2 — a class may spread its
	// bound procs across sibling files, so generation can't happen until every file
	// has been seen.
	Pending :: struct {
		script:   Script,
		out_path: string,
	}
	Helper :: struct {
		path: string,
		src:  string,
	}
	pending := make([dynamic]Pending)
	helpers := make([dynamic]Helper)
	lintable := make([dynamic]Helper) // EVERY package file — scripts and helpers both
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

		append(&lintable, Helper{path = path, src = src})
		script, has := parse_script(path, src)
		if !has {
			append(&helpers, Helper{path = path, src = src})
			continue
		}

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

		append(&pending, Pending{script = script, out_path = out_path})
	}

	// Pass 2: multi-file classes. A helper file's procs whose first param is
	// `^<Struct>` of a sibling script join that script's tables — methods, commands,
	// lifecycles, rpcs — exactly as if they lived in the class's home file. Parse
	// failures stay silent here (odin build reports them properly).
	for h in helpers {
		file := ast.File {
			fullpath = h.path,
			src      = h.src,
		}
		p := parser.default_parser()
		p.err = silent_parse_diag
		p.warn = silent_parse_diag
		if !parser.parse_file(&p, &file) {continue}
		for &pend in pending {
			scan_bound_procs(&pend.script, h.path, h.src, &file)
		}
	}

	// Lint every package file now that the full set of script structs is known —
	// a helper file's `self: ^Golf` param is only recognizable once Golf's home
	// file has been parsed (lint.odin: the self-vs-owner footgun).
	script_structs := make(map[string]bool)
	defer delete(script_structs)
	for &pend in pending {script_structs[pend.script.struct_name] = true}
	for l in lintable {lint_handles(l.path, l.src, script_structs)}

	// THE METHOD TRAP lint: inside a class's HOME file, an attributed or
	// lifecycle-named proc receiving a DIFFERENT script struct binds to
	// nothing — name it at build time with the move-it instruction.
	home := make(map[string]string) // script home path -> its struct name
	defer delete(home)
	for &pend in pending {home[pend.script.path] = pend.script.struct_name}
	for l in lintable {
		if own, is_home := home[l.path]; is_home {
			lint_misplaced(l.path, l.src, own, script_structs)
		}
	}

	// Pass 3: name pairing. Collect every `*_then` / `*_spawned` / `*_freed`
	// proc in the package (they may live anywhere — a game-threaded proc's
	// first param is the GAME struct, so the per-class bound-proc scan never
	// claims them), then pair each script's commands with their consequences
	// and each entity tag with its hooks, validating every shape.
	then_idx := make(map[string]Then_Candidate)
	defer delete(then_idx)
	method_claims := make([dynamic]Method_Claim)
	defer delete(method_claims)
	for l in lintable {
		file := ast.File {
			fullpath = l.path,
			src      = l.src,
		}
		p := parser.default_parser()
		p.err = silent_parse_diag
		p.warn = silent_parse_diag
		if !parser.parse_file(&p, &file) {continue}
		scan_then_procs(&then_idx, l.path, l.src, &file)
		scan_method_claims(&method_claims, l.path, l.src, &file, script_structs)
	}
	by_struct := make(map[string]^Script)
	defer delete(by_struct)
	script_snakes := make(map[string]bool)
	defer delete(script_snakes)
	for &pend in pending {
		by_struct[pend.script.struct_name] = &pend.script
		script_snakes[to_snake(pend.script.struct_name)] = true
	}
	seen_entity_ids := make(map[int]string)
	defer delete(seen_entity_ids)
	for &pend in pending {
		resolve_then(&pend.script, &then_idx)
		resolve_tick_then(&pend.script, &then_idx)
		resolve_entities(&pend.script, by_struct, &seen_entity_ids, &then_idx)
	}
	warn_unclaimed_thens(&then_idx, script_snakes)
	lint_method_claims(method_claims[:], by_struct)

	// Generate, now that every file's contribution is in (validation too — a
	// @(gd_command) found in a helper still needs its class's replicate/net_id).
	for &pend in pending {
		validate_script(&pend.script)
		if had_error {continue}
		gen := generate(&pend.script)
		if werr := os.write_entire_file(pend.out_path, transmute([]byte)gen); werr != nil {
			errorf("cannot write %q", pend.out_path)
			continue
		}
		fmt.printfln("scriptgen: wrote %s", pend.out_path)
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
