package scriptgen

// ----------------------------------------------------------------------------
// scriptgen — the Phase 3.5 codegen preprocessor for odin_godot.
//
// Authors write a CLEAN `.odin` script (struct-tag exports, plain typed lifecycle
// /method procs, `//gd:` markers). For a whole scripts dir `scriptgen` emits ONE
// `odin_godot_scripts.gen.odin` (same package) holding one SECTION per annotated
// source: the verbose Phase-3 registration boilerplate those scripts otherwise
// hand-write — the uniform Variant trampolines, the `@(private="file")` backing
// arrays, the signal-emit helpers, and the `@(init) rt.register(Class_Desc{...})`.
// The generated output is byte-for-byte EQUIVALENT in effect to the hand-written
// Phase-3 showcase scripts.
//
// ONE ARTIFACT PER DIR: a package dir with annotated scripts gets exactly one generated
// file, the consolidated `odin_godot_scripts.gen.odin`; the module ROOT gets two more,
// the `odin_godot_guard.gen.odin` staleness guard and the `odin_godot_boot.gen.odin`
// shim. Everything else matching `*.gen.odin` anywhere in the tree is swept as an orphan,
// which is also what migrates a project off the old one-gen-file-per-source layout on its
// first build.
//
// SCRIPT SUBPACKAGES: a module is a TREE, not one flat dir. Every subdirectory holding
// authored `.odin` sources is its own Odin package and is run through the same per-dir
// pipeline, so engine-native script classes (HUD widgets, UI, fx, tools) live in
// `scripts/ui/` and are attachable from there. A subdir with annotated scripts gets its
// own consolidated `odin_godot_scripts.gen.odin`; one without gets nothing (the plain
// helper package it always was). Still ONE dll per module — the root package links the
// subpackages through the import manifest in its guard file. Root-only by construction:
// the boot shim (a second `odin_scripts_boot` export is a duplicate-symbol link error),
// the staleness guard (which hashes the WHOLE tree), and every KIT annotation (wire
// contract, lanes, input struct — see check_subpkg_kit).
//
// SINGLE-FILE AUTHORING: the authored `.odin` is the file the user attaches to a node
// (the loader reads its `//gd:class` marker to bind it to the compiled class). scriptgen
// emits only build artifacts beside the sources; there is no separate resource stub.
// The `.gen.odin` suffix is what makes the loader ignore them as attachable scripts.
//
// Parsing is done PROPERLY with `core:odin/parser` + `core:odin/ast` (the struct,
// its fields/tags — including the typed signal fields — and the procs + their typed
// signatures). The `//gd:` comment markers (extends/class/tool/icon) — which Phases
// 1-3 already recognize — are scanned from the source text, exactly as the core's
// ResourceLoader does.
//
// Usage:
//   scriptgen <scripts_dir>
//     - emits one odin_godot_scripts.gen.odin (plus the guard and boot shims) in <scripts_dir>
//   (a legacy `-res:<dir>` flag is accepted but ignored — stubs are no longer emitted.)
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:hash"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import decl "godot:decl"

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
		   !strings.has_prefix(pointee, "gd.") &&
		   !strings.has_prefix(pointee, "godot.") {
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
		return Variant_Info {
				strings.concatenate({".", name}),
				strings.concatenate({"gd.", name}),
				.Other,
			},
			true
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
		   len(base) > 0 &&
		   base[0] >= 'A' &&
		   base[0] <= 'Z' &&
		   !strings.contains_rune(base, '(') {
			return Variant_Info{".Object", "rawptr", .Other}, true
		}
	}
	return {}, false
}

LIFECYCLE_KEYWORDS := [?]string {
	"physics_process",
	"process",
	"ready",
	"enter_tree",
	"exit_tree",
	"reload",
}

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
	// Godot class spelling derived from a TYPED resource handle (`bullet: gd.Packed_Scene`
	// -> "PackedScene") when the tag spells no `resource=` itself. Published via
	// Field_Meta.resource_class so the runtime can synthesize the Resource_Type hint —
	// reflection can't recover it (every refcounted handle erases to the same ^rawptr),
	// and WITHOUT the hint inst_set skips the refcount hold and the field dangles.
	res_class: string,
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
// The path-qualified form `@(gd_connect="Path/To/Node:signal")` names another EMITTER,
// resolved at READY like an `onready=` ref (split at the LAST ':' — node names cannot
// contain one); `path` is "" for the plain owner form.
Connection_Info :: struct {
	signal:  string, // the signal name on the emitter
	method:  string, // the GDScript-exposed method name (the @(gd_method) gd_name)
	path:    string, // emitter node path ("" = the owner itself)
	indexed: bool, // path holds one `%d`: probe 0,1,2,… and bind each index (trailing arg)
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

// A networked field: `gd:"replicate"` (delta lane), `gd:"owner"` (owner-streamed),
// or `gd:"predict"` (kit/sim), each with its own option set. The LANE is the first
// token — `owner`/`predict` are not options, they select which of the three writers
// owns the field's bytes, and `owner`/`predict` below are that choice resolved.
// scriptgen records name, options, and declaring type context. The canonical ABI
// walk resolves the field recursively before generation; target-side size/alignment
// assertions then pin that result in the consumer compiler.
Replicate_Info :: struct {
	field:        string, // leaf field name (diagnostics/display)
	loc:          Loc, // declaration site for recursive wire-ABI diagnostics
	type_text:    string, // the field's declared type (subst-applied for block fields) —
	type_dir:     string, // package context in which type_text resolves
	type_imports: map[string]string,
	// Access segments from the entity-struct root to this field, e.g. {"hp"} for a
	// top-level field, {"move","x"} for a field reached through a `using`/embedded
	// sub-struct. generate.odin turns this into the offset/size/POD expressions
	// (nested-replicate-fields KB doc). Always at least length 1.
	path:         []string,
	interp:       bool, // remote peers interpolate this field
	owner:        bool, // part of the owner-authoritative unreliable stream
	predict:      bool, // kit/sim lane: server-sim-authoritative, client-predicted + reconciled
	lerp:         string, // knet.Lerp_Kind literal (".F32"/".F64"/".Quat"/".Custom"); "" = Snap
	blend:        string, // `interp=NAME`: the author's knet.Blend_Proc, spliced verbatim
	wire:         string, // knet.Wire_Kind literal (".F16"/".Custom"); "" = raw struct bytes
	codec:        string, // `wire=NAME`: the author's knet.Wire_Codec, spliced verbatim
	abi_size:     int, // recursively validated struct-side byte width
	abi_align:    int, // canonical target-independent alignment (compile-time asserted)
	wire_size:    int, // resolved packet width (raw/F16/custom)
	slack:        string, // `slack=N`: per-field kit/sim reconcile tolerance, the numeric literal
	// spliced as f32 ("" = inherit the lane default). predict floats only.
	glide:        string, // `glide=N`: per-field render-error half-life (seconds). predict+interp floats.
	cut:          string, // `cut=N`: per-field snap threshold (world units). predict+interp floats.
	// The field's `<class>_<path>_edge` half (resolve_edges): delta-lane
	// change presentation — the PROC is the subscription, no tag. "" = none.
	edge_proc:    string,
	edge_game:    string, // its optional leading game param type ("" = self-first)
}

// A `gd:"backup"` field — HOST-LOCAL state that rides host migration and
// save/resume. generate.odin emits a version-hashed <class>_backup_write/_read
// codec over these, so a takeover restores the campaign (not a diorama) with
// no hand-matched write/read lists to drift out of sync.
Backup_Kind :: enum {
	Pod, // a scalar, a POD struct, or a fixed [N]POD array — write_pod whole
	Map, // map[POD]POD — length-prefixed key/value loop
	Dyn, // [dynamic]POD — length-prefixed element loop
}

Backup_Info :: struct {
	field: string, // leaf name (diagnostics)
	path:  []string, // access segments from the class root (nesting, like Replicate_Info)
	kind:  Backup_Kind,
	key:   string, // Map: the key type text
	elem:  string, // Map: the value type text; Dyn: the element type text
}

// One @(gd_command) arg. Command args cross the wire, so the allowed types are
// kit/net's wire primitives — `wire` is the read_/write_ proc suffix and
// `type_text` the (knet.-normalized) spelling spliced into the wrapper signature.
Command_Arg :: struct {
	name:      string,
	type_text: string,
	wire:      string,
}

Command_Outcome :: struct {
	name:      string,
	type_text: string,
}

// The value carried by @(gd_command=...). Bare attributes resolve to the secure
// owner-only default. New declarations carry a typed knet.Action_Policy
// expression; `legacy` retains the old comma-string reader as a migration path.
Command_Config :: struct {
	policy_expr: string,
	legacy:      string,
}

// One @(gd_command[=POLICY]) proc — a host-authoritative action with a typed
// access/prediction/argument policy shared by both execution models.
Command_Info :: struct {
	proc_name:       string, // author proc (chest_open / gun_fire) — names the decode thunk (+ a direct command's wrapper)
	loc:             Loc,
	name:            string, // entity-level command name: a direct command's stripped verb ("open"), or a
	// COMPOSED one's "<path>_<verb>" ("gun_fire") — drives the index const + wrapper
	policy_expr:     string, // generated knet.Action_Policy expression (default/preset/literal)
	policy_access:   string, // canonical wire ABI value: owner / any-seat / authority
	policy_predict:  bool, // canonical wire ABI value: optimistic vs authority-confirmed
	policy_max_args: int, // resolved byte ceiling (0 never survives parsing; default = 4096)
	args:            [dynamic]Command_Arg,
	outcomes:        [dynamic]Command_Outcome, // in-process values returned after the applied bool
	// Verb-composition: a command whose proc lives on an EMBEDDED sub-struct field is hoisted
	// onto the entity (the dual of a nested `gd:"replicate"` field). `path` is the access path
	// from the entity root to that field ({"gun"} or {"loadout","primary"}); nil/empty = a
	// DIRECT command on the entity (the decode thunk routes to `self`). `owner` = the sub-proc
	// takes a `^Entity` param right after its receiver — a pointer, so never a wire arg —
	// which scriptgen fills with `self` so the block can read/write its wielder. pkg_alias /
	// pkg_path qualify + import the sub-proc's package into the generated file ("" = the
	// entity's own package: no qualifier, no import).
	path:            []string,
	owner:           bool,
	// The verb declared the ISSUER param — `by: knet.Player_Id` right after the
	// receiver (after the wielder for a composed block). Framework-filled, never
	// a wire arg: the predicate learns WHO unforgeably (ctx.me on the issuing
	// peer, the resolved sender on the host — the same values its `_then` gets),
	// so "which side am I" can't be a client-claimed argument.
	wants_by:        bool,
	pkg_alias:       string,
	pkg_path:        string,
	// Consequence pairing (`<wrapper>_then`): a verb may return `(bool, payload…)`
	// and the game may declare a name-paired consequence proc — the typed,
	// authority-only "and then…" that replaces scratch fields + the untyped hook
	// switch. `payload_count` is how many results ride behind the applied bool
	// (they never cross the wire — the consequence runs in the same process as
	// the authoritative verb). `then_proc` = "" means no consequence declared;
	// `then_game` is the leading game param's pointee ("Scrapyard", "" = the
	// entity-local form) — generated code casts ctx.game_user/env.user to it.
	payload_count:   int, // mirrors len(outcomes); retained for compact generation loops
	then_proc:       string,
	then_game:       string,
	// `<proc>_apply` (SIM-lane verbs only): the predicted-effect half resims
	// RE-RUN with the ledgered wire args — exact relative effects where the
	// recorded-bytes patch would re-pin stale absolutes. "" = patch mode.
	apply_proc:      string,
}

// An `entity=Name:id` declaration on an exported PackedScene field — one row
// of the kboot entity table (factory consolidation): the scene stays an
// editor-wired export; the tag names the entity struct it bodies and its
// STABLE wire id (explicit on purpose — auto-numbering would silently
// renumber saves/rejoins/backups on any edit).
// One generated acid probe — the mechanical half of every game's hand-written
// queries.odin: a @(gd_method) window the test driver (driver.gd) reads
// replicated state through. Per `entity=` kind: a count, a my-id, and one
// per replicated SCALAR field (compound fields stay hand-written — a derived
// view is game-shaped). A hand-written proc wearing the name wins, like the
// census.
Probe_Form :: enum {
	Field, // probe_<kind>_<field>(id) — 0 = my entity of that kind
	Count, // probe_<kind>_count()
	My, // probe_my_<kind>() — my entity's net id, 0 = none
}

Probe_Info :: struct {
	form:    Probe_Form,
	name:    string, // the gd-visible name ("probe_kicker_hp")
	tsnake:  string, // entity kind, snaked ("kicker")
	target:  string, // the entity struct ("Kicker")
	access:  string, // Field only: the access path on the entity ("score.l")
	float:   bool, // Field only: gd.Float return (f32/f64); else gd.Int
	boolish: bool, // Field only: bool field — returns 1/0
}

Entity_Tag :: struct {
	field:                                                string, // the scene field (offset_of target on the game struct)
	target:                                               string, // the entity struct the scene bodies ("Mob")
	type_id:                                              int, // the stable ksess.Entity_Type value
	line:                                                 int,
	// The tag's trailing ENTITY tokens (not export specs): the kind's declared
	// knobs, emitted on its kboot.Entity_Kind row.
	stream_hz:                                            int, // `stream_hz=N` — owner-stream rate, per type, every peer
	avatar:                                               bool, // `avatar` — this kind is a seat's body (host takeover parks it)
	// Resolved by resolve_entities (module-wide): the optional name-paired
	// typed hooks ("" = not declared).
	spawned:                                              string, // <target_snake>_spawned — MAKE time (fields unset; bookkeeping)
	freed:                                                string, // <target_snake>_freed
	born:                                                 string, // <target_snake>_born — Ev_Spawned time (fields SET; the dress),
	// dispatched typed from the generated <game>_events
	has_tick:                                             bool, // the target declares @(gd_tick) — the kinds row carries its Sim_Set
	gen_spawn:                                            bool, // emit the typed `<entity>_spawn` helper (hand-written name wins)
	// Which census accessors to emit (resolve_census): a hand-written proc
	// of the same name suppresses that one, keeping its meaning.
	gen_ref, gen_of, gen_owned, gen_my, gen_ids, gen_all: bool,
}

// The class's @(gd_sample)/@(gd_step) procs — the lane's GAME half (kit/sim).
// scriptgen generates the rawptr thunks and a `<snake>_lane_init` wiring proc
// that carries the input size, the typed sample destination, and the step's
// authority gate — game code never casts a rawptr or repeats size_of, and
// sampling into the wrong struct is a build error (resolve_sim), not a
// haunted misread.
Sim_Proc_Info :: struct {
	proc_name:  string,
	line:       int,
	wants_tick: bool, // step only: declared the optional `tick: u64` param
	input_type: string, // sample only: the `input: ^T` param's T
	validate:   string, // sample only: typed semantic validator/sanitizer proc
}

// One input CLASS the lane carries — a distinct @(gd_tick) input struct type,
// its wire id (assigned package-wide by resolve_sim, sorted by type name; the
// primary is 0), and the @(gd_sample) that fills it. A single-input game has
// one of these; a game driving two entity kinds has one per kind.
Input_Class_Info :: struct {
	class_id:    int,
	type_name:   string,
	sample:      string, // the @(gd_sample) proc filling it ("" = none: those entities coast)
	validate:    string, // optional game predicate paired by @(gd_sample="validate[=PROC]")
	constraints: []Input_Field_Constraint, // generated @(gd_input) field sanitizer/checks
	line:        int,
	abi_size:    int,
	abi_align:   int,
}

// One declarative rule from a field of an @(gd_input) struct. The generator
// deliberately keeps these as source literals: the script package's compiler
// remains the final authority on the field type while scriptgen supplies an
// early, field-named diagnostic for invalid combinations.
Input_Field_Constraint :: struct {
	field:      string,
	type_text:  string,
	array_len:  int, // 0 = scalar; positive = fixed array (the generated loop bound)
	range_min:  string,
	range_max:  string,
	mask:       string,
	finite:     bool,
	unit:       bool,
	enum_check: bool,
}

// The one @(gd_tick) proc a class may declare — its sim-lane step (kit/sim).
// scriptgen generates the rawptr thunk and the `<snake>_sim_set` the game
// hands to ksim.lane_track_set.
Tick_Info :: struct {
	proc_name:       string,
	input_type:      string, // the input param's type text, spliced verbatim ("" = inputless)
	input_class:     int, // resolved package-wide (resolve_sim): the wire class its input rides
	input_abi_size:  int, // recursive canonical width (target-side asserted before emission)
	input_abi_align: int,
	wants_lane:      bool, // trailing `lane: ^ksim.Lane` param — threaded by the thunk
	line:            int,
	contested:       bool, // @(gd_tick="contested"): every peer predicts this entity
	payload_count:   int, // results = FACTS the tick learned (fired, dashed, landed) —
	// threaded to the name-paired halves below
	payload_types:   [dynamic]string, // each fact's declared type text, in result order
	then_proc:       string, // `<proc>_then`: AUTHORITY-only consequence ("" = none)
	then_game:       string, // its optional leading game param type ("" = self-first shape)
	fx_proc:         string, // `<proc>_fx`: presentation ("" = none). Without `mine` it fires
	// on the owning peer's LIVE pass only; with it, on EVERY screen.
	fx_game:         string,
	fx_mine:         bool, // the _fx declares `mine: bool` after self: every-screen
	// presentation — event ticks broadcast the fact tuple (SIM_FACT),
	// watchers fire on the watch clock, the live pass fires inline
	payload_wires:   [dynamic]string, // wire suffix per fact (filled iff fx_mine — facts
	// cross the wire, so they must be wire primitives)
}

// One declared presentation cue — preferably `@(gd_cue)`, with `@(gd_fact)`
// retained as the original compatible spelling — on a `<event>_fx` proc.
// scriptgen generates the announce DOOR under the bare event name: the
// step (or an authority half) calls `<event>(l, anchor?, args…)` and the door
// holds every gate — the authority broadcasts (SIM_FACT, watchers fire on the
// watch clock), the causer's live pass fires now (mine=true), a resim replay
// never re-fires, and screens with no part stay silent. Resolved package-wide
// onto the lane OWNER (resolve_facts): facts ride the lane's watch clock.
Fact_Info :: struct {
	name:         string, // the bare event name — the generated door (fx name minus `_fx`)
	fx_proc:      string, // the author's half: `<name>_fx`
	game:         string, // the leading game param's struct name (the lane owner)
	anchor:       string, // the anchor param's struct name ("" = anchorless world fact)
	anchor_param: string, // the author's name for the anchor param (the door mirrors it)
	anchor_index: int, // index in entity_* (-1 = no entity anchor)
	entity_names: [dynamic]string, // typed entity refs before `mine`, in author order
	entity_types: [dynamic]string, // struct name per entity ref; the anchor rides the header,
	// other refs ride as Net_Id values in the cue tuple
	arg_names:    [dynamic]string, // wire args after `mine`, author-named
	arg_types:    [dynamic]string, // declared type text per arg (spliced into the door)
	arg_wires:    [dynamic]string, // wire suffix per arg
	line:         int,
	path:         string,
}

// One declared typed app-message — `@(gd_message="TAG")` on a handler
// `proc(self: ^Owner, from: knet.Player_Id, msg: T)`. scriptgen generates the
// game-owned Typed_Route(T) storage, a `<class>_messages` registration proc (the
// game calls it once in ready()), and `<proc>_send` / `<proc>_send_to` doors over
// the runtime typed-route API (session_app_listen / session_app_send_typed). A
// recursively validated canonical raw payload is decoded for the handler; the
// tag is the game's SES_APP tag byte.
Message_Info :: struct {
	proc_name:    string, // the author's handler proc (drives the route var + send wrappers)
	name:         string, // struct-prefix-stripped (the diagnostic / fingerprint name)
	game:         string, // the receiver struct — the class whose `_messages` proc registers it
	payload_type: string, // the `msg: T` type text — its layout folds into NET_FINGERPRINT
	tag_ident:    string, // the declared SES_APP tag constant, spliced verbatim (e.g. TAG_WHISPER)
	line:         int,
	path:         string,
	abi_size:     int,
	abi_align:    int,
}

Script :: struct {
	path:              string, // source file path (diagnostics)
	imports:           map[string]string, // declaring file imports (canonical wire-type resolution)
	godot_alias:       string, // the file's `godot:godot` import alias ("" = not imported)
	pkg:               string,
	struct_name:       string,
	class_name:        string,
	base:              string,
	base_line:         int, // 1-based line of the `//gd:extends` marker (0 = none written; base was DERIVED from the owner handle)
	doc:               string, // `///` doc comment above the script struct (class description)
	marked:            bool, // saw at least one valid `//gd:` marker (intent signal for diagnostics)
	tool:              bool,
	icon:              string, // `//gd:icon <res-path>` — custom class icon (""=none)
	groups:            [dynamic]string, // `//gd:group a b` — joined on READY by the core
	exports:           [dynamic]Export_Info,
	onready_scripts:   [dynamic]Onready_Script_Ref, // `^ScriptStruct` onready fields, validated module-wide (resolve_onready_scripts)
	lifecycles:        [dynamic]Lifecycle_Info,
	methods:           [dynamic]Method_Info,
	signals:           [dynamic]Signal_Info,
	connections:       [dynamic]Connection_Info,
	rpcs:              [dynamic]Rpc_Info,
	replicates:        [dynamic]Replicate_Info,
	backups:           [dynamic]Backup_Info, // gd:"backup" host-local migration/save state
	commands:          [dynamic]Command_Info,
	entities:          [dynamic]Entity_Tag, // entity=Name:id scene fields (the kboot table)
	net_id_type:       string, // type text of a `net_id` field ("" = none) — commands require knet.Net_Id
	tick:              Tick_Info, // proc_name == "" = the class doesn't tick
	block_ticks:       [dynamic]Hoisted_Tick, // embedded blocks' ticks, entity-tick-first order
	samples:           [dynamic]Sim_Proc_Info, // @(gd_sample): the lane's device reads — one per input class
	step:              Sim_Proc_Info, // @(gd_step): the EVERYWHERE world pass (live + resim)
	step_auth:         Sim_Proc_Info, // @(gd_step="authority"): the host-only world pass
	// The authority pass is BOOT-routed (resolve_sim): a tickless package has no
	// lane, so `<snake>_step(self, ticks)` is generated instead of lane wiring —
	// the coop game's fixed step, role-gated, with the same-frame edge pass inside.
	step_boot:         bool,
	input_classes:     [dynamic]Input_Class_Info, // resolved package-wide (resolve_sim), on the lane OWNER: every input class, sorted by id (0 = primary)
	facts:             [dynamic]Fact_Info, // declared presentation cues (resolve_facts), on the lane OWNER — doors + decode thunks + the fact table ride its gen file
	messages:          [dynamic]Message_Info, // declared typed app-messages (@(gd_message)) — route storage + a `_messages` registration proc + send doors ride this class's gen file
	boot_field:        string, // the kboot.Boot field's name ("" = none) — generates the standard transport forwards
	boot_fields:       int, // direct Boot fields (the net facade needs exactly one)
	session_field:     string, // the direct ksess.Session field, when unique
	session_fields:    int,
	comms_field:       string, // the direct kcomms.Comms field, when unique
	comms_fields:      int,
	lane_field:        string, // the direct ksim.Lane field, when unique
	lane_fields:       int,
	// A conventional Boot + Session + Comms shell gets the three generated
	// lifecycle doors. A lane owner additionally needs one direct Lane. Each
	// bool yields independently to a hand-written proc of the same name.
	net_attach:        bool,
	net_pump:          bool,
	net_detach:        bool,
	std_forwards:      [dynamic]string, // which standard forwards were synthesized (bodies emitted by generate)
	probes:            [dynamic]Probe_Info, // generated acid probes (resolve_probes; bodies emitted by generate)
	event_halves:      [dynamic]Event_Half, // session-event halves (resolve_session_events) — the generated `<snake>_events` dispatch
	embodied:          string, // `<snake>_embodied(self, id)` — MY avatar-kind entity was born (resolve_entities; needs an `avatar` kind)

	// Migration halves (resolve_migration): the host-migration dance's four
	// name-paired seams — kboot.boot_migration's generated hook table. "" =
	// undeclared; any declared = the table + the events-tail drain are emitted.
	succ_backup:       string, // `<snake>_backup(self, w)` — host: the campaign blob
	succ_took_over:    string, // `<snake>_took_over(self, r)` — heir: read blob + mend
	succ_wiped:        string, // `<snake>_wiped(self)` — non-entity pools, post-wipe
	succ_migrating:    string, // `<snake>_migrating(self, step, target, try)` — the words

	// `gd:"profile=Type"` on the ksess.Session field: the session-profile
	// row type — folded into NET_FINGERPRINT, installed in the ready thunk.
	profile_type:      string, // the row struct's name ("" = none declared)
	profile_ses:       string, // the Session field the install targets
	profile_abi_size:  int,
	profile_abi_align: int,
}

// A SCRIPT-RESOLVING onready field (`hud: ^hud `gd:"onready=Path"``): the pointee names
// a script struct whose declaring file may parse after this one, so parse records it and
// resolve_onready_scripts validates the name once the whole module is in.
Onready_Script_Ref :: struct {
	field:  string, // the field's label (error messages)
	target: string, // the pointee identifier — must be a script struct in the module
	loc:    Loc,
}

// One session event a game shell paired a half with. The BARE half fires
// wherever the event fires on this peer; the `_then` half fires on the
// AUTHORITY alone — the generated dispatch holds the role gate, so no
// event-drain switch (or is_host inside it) survives in game code.
Event_Half :: struct {
	ev:        int, // index into SESSION_EVENTS
	bare:      string, // "" = undeclared
	then_proc: string, // "" = undeclared (legal only on .Every events)
}

Session_Ev_Role :: enum u8 {
	Every, // both roles hear it — `_then` narrows to the authority
	Client, // never reaches the authority — a `_then` could never fire
	Host, // already authority-only — a `_then` would be redundant
}

Session_Ev_Param :: struct {
	name:  string, // canonical param name (for error hints)
	type_: string, // the param type as spelled in hints ("knet.Player_Id")
	field: string, // the Ev struct field the dispatch reads ("e.id")
}

Session_Ev :: struct {
	suffix:  string, // half name = <game snake> + "_" + suffix
	variant: string, // the ksess.Event union variant ("Ev_Player_Joined")
	role:    Session_Ev_Role,
	params:  []Session_Ev_Param,
}

// The session's event surface as pairable halves — kit/session's Event union,
// one row per variant, roles from the (client)/(host) annotations there. The
// entity-cluster suffixes carry an `entity_` prefix so they never collide with
// the census `<entity>_spawned`/`_freed` hooks (which fire BEFORE the spawn
// tuple's fields apply; these fire after — the initial-dress home).
//
// WHY THIS IS TRANSCRIBED AND NOT GENERATED, since it is the one table in the
// repo that still is. scriptgen is a BUILD-TIME binary: kit/session is source it
// PARSES, never source it imports, and importing it to read the union would make
// a runtime package a build dependency of the tool that generates that package's
// callers — the build graph would have to produce the generator from the thing
// the generator produces. Reading the union out of source at scriptgen startup
// is the other direction and no better: every game build would then depend on
// text-scraping a kit file, and the failure mode of a scrape that silently
// matches nothing is an EMPTY event table, which generates a game where no
// session half fires at all. Neither is worth it for a union that changes a few
// times a year.
//
// So the mirror stays and TWO guards make a forgotten variant unshippable, one
// per direction it can be forgotten in:
//
//   * kit/boot/forward.odin holds one non-`#partial` switch over every variant,
//     so a new Event does not COMPILE until the kit has decided about it.
//   * tests/scriptgen asserts this table's `variant` column equals the union,
//     so a new Event is also a pairable half in every GAME. Without that half
//     the failure is the quietest one available: the author writes the proc,
//     nothing generates a call, and it simply never runs.
//
// Roles and params still cannot be checked mechanically — nothing but reading
// the variant says whether a client alone hears it — so a NEW row's role is a
// judgement, and the test only guarantees somebody had to make it.
SESSION_EVENTS := [?]Session_Ev {
	{
		suffix = "seated",
		variant = "Ev_Seated",
		role = .Every,
		params = {{"me", "knet.Player_Id", "e.me"}},
	},
	{
		suffix = "welcomed",
		variant = "Ev_Welcomed",
		role = .Client,
		params = {{"me", "knet.Player_Id", "e.me"}},
	},
	{
		suffix = "player_joined",
		variant = "Ev_Player_Joined",
		role = .Every,
		params = {{"id", "knet.Player_Id", "e.id"}, {"rejoin", "bool", "e.rejoin"}},
	},
	{
		suffix = "player_left",
		variant = "Ev_Player_Left",
		role = .Every,
		params = {{"id", "knet.Player_Id", "e.id"}},
	},
	{suffix = "host_left", variant = "Ev_Host_Left", role = .Client, params = {}},
	{suffix = "join_failed", variant = "Ev_Join_Failed", role = .Client, params = {}},
	{
		suffix = "join_denied",
		variant = "Ev_Join_Denied",
		role = .Client,
		params = {{"reason", "ksess.Deny_Reason", "e.reason"}},
	},
	{suffix = "kicked", variant = "Ev_Kicked", role = .Client, params = {}},
	{
		suffix = "backup_target",
		variant = "Ev_Backup_Target",
		role = .Host,
		params = {{"player", "knet.Player_Id", "e.player"}},
	},
	{
		suffix = "succession",
		variant = "Ev_Succession",
		role = .Client,
		params = {{"successor", "knet.Player_Id", "e.successor"}},
	},
	{
		suffix = "backup_received",
		variant = "Ev_Backup_Received",
		role = .Client,
		params = {{"size", "int", "e.size"}},
	},
	{
		suffix = "entity_spawned",
		variant = "Ev_Spawned",
		role = .Every,
		params = {
			{"id", "knet.Net_Id", "e.id"},
			{"type", "ksess.Entity_Type", "e.type"},
			{"owner", "knet.Player_Id", "e.owner"},
		},
	},
	{
		suffix = "entity_resynced",
		variant = "Ev_Resynced",
		role = .Client,
		params = {
			{"id", "knet.Net_Id", "e.id"},
			{"type", "ksess.Entity_Type", "e.type"},
			{"owner", "knet.Player_Id", "e.owner"},
		},
	},
	{
		suffix = "entity_despawned",
		variant = "Ev_Despawned",
		role = .Client,
		params = {{"id", "knet.Net_Id", "e.id"}},
	},
	{
		suffix = "entity_changed",
		variant = "Ev_Entity_Changed",
		role = .Client,
		params = {{"id", "knet.Net_Id", "e.id"}},
	},
	{
		suffix = "owner_changed",
		variant = "Ev_Owner_Changed",
		role = .Every,
		params = {
			{"id", "knet.Net_Id", "e.id"},
			{"owner", "knet.Player_Id", "e.owner"},
			{"prev", "knet.Player_Id", "e.prev"},
		},
	},
	{suffix = "stats_updated", variant = "Ev_Stats_Updated", role = .Client, params = {}},
	{
		suffix = "profile_changed",
		variant = "Ev_Profile_Changed",
		role = .Every,
		params = {{"player", "knet.Player_Id", "e.player"}},
	},
	{
		suffix = "state_applied",
		variant = "Ev_State_Applied",
		role = .Client,
		params = {{"entities", "int", "e.entities"}},
	},
	{
		suffix = "blob_changed",
		variant = "Ev_Blob_Changed",
		role = .Every,
		params = {{"id", "knet.Net_Id", "e.id"}, {"size", "int", "e.size"}},
	},
	{
		suffix = "command_executed",
		variant = "Ev_Command_Executed",
		role = .Host,
		params = {
			{"ok", "bool", "e.ok"},
			{"player", "knet.Player_Id", "e.player"},
			{"entity", "knet.Net_Id", "e.entity"},
			{"cmd", "u16", "e.cmd"},
			{"reason", "knet.Action_Reject_Reason", "e.reason"},
			{"seq", "knet.Intent_Seq", "e.seq"},
			{"model", "knet.Action_Model", "e.model"},
		},
	},
	{
		suffix = "command_confirmed",
		variant = "Ev_Command_Confirmed",
		role = .Client,
		params = {
			{"seq", "knet.Intent_Seq", "e.seq"},
			{"entity", "knet.Net_Id", "e.entity"},
			{"cmd", "u16", "e.cmd"},
			{"model", "knet.Action_Model", "e.model"},
		},
	},
	{
		suffix = "command_rejected",
		variant = "Ev_Command_Rejected",
		role = .Client,
		params = {
			{"seq", "knet.Intent_Seq", "e.seq"},
			{"entity", "knet.Net_Id", "e.entity"},
			{"cmd", "u16", "e.cmd"},
			{"reason", "knet.Action_Reject_Reason", "e.reason"},
			{"model", "knet.Action_Model", "e.model"},
		},
	},
}

// The host-migration halves — kboot.boot_migration's seams, pairable like
// session events (on the SHELL, by exact name). Session_Ev_Param reused for
// the shape hints; `field` is unused (the kit calls these, not a dispatch).
Migration_Half_Spec :: struct {
	suffix: string,
	params: []Session_Ev_Param,
	what:   string, // one line of role, for the shape error
}

MIGRATION_HALVES := [?]Migration_Half_Spec {
	{
		suffix = "backup",
		params = {{"w", "^knet.Writer", ""}},
		what = "the HOST writes the campaign blob it rides on every backup refresh",
	},
	{
		suffix = "took_over",
		params = {{"r", "^knet.Reader", ""}},
		what = "the HEIR reads the blob back and mends, after the kit resumed the run",
	},
	{
		suffix = "wiped",
		params = {},
		what = "the non-entity pools clear, after the kit's census-driven wipe",
	},
	{
		suffix = "migrating",
		params = {
			{"step", "kboot.Migrate_Step", ""},
			{"target", "string", ""},
			{"try", "int", ""},
		},
		what = "the dance's words — one call per arm, mechanics already ran",
	},
}

had_error: bool

// Set while a SPECULATIVE pass runs (the subpackage kit pre-scan, see prescan_subpkg_kit):
// every diagnostic and every had_error is the REAL pass's to report, so a file parsed
// twice never complains twice. Nothing outside that pre-scan touches it.
g_quiet_diag: bool

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
	if g_quiet_diag {return}
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
	if g_quiet_diag {return}
	diag_prefix("warning", loc)
	fmt.eprintf(format, ..args)
	fmt.eprintln()
}

// ---- yields: the manual-override pattern, said out loud ----------------------
//
// NAME SHADOWING is THE way to take a generated thing over by hand: write a proc
// with the generated name and it wins. Census accessors, acid probes and the
// four standard transport forwards all work that way — and all three did it in
// COMPLETE SILENCE, so a typo'd override (`runner_of` where the entity is
// `Runner_Bot`) read as "the generation just didn't happen" and a deliberate one
// left no evidence it had taken effect. These go to stdout beside the
// `scriptgen: wrote …` lines because a yield is part of what the run PRODUCED,
// not a complaint about it.
//
// (A declared cue's announce door is the one exception, and it refuses instead of
// yielding — see resolve_facts, where the reason is written down.)
@(private = "file")
g_yielded: map[string]bool

// `what` names the family ("census accessor", "acid probe", ...). Once per run
// per name: the census resolves per script, so a shared module-wide name would
// otherwise print once per file that reaches it.
note_yield :: proc(what, name: string) {
	if g_yielded[name] {return}
	g_yielded[strings.clone(name)] = true // callers pass tprintf'd names; the set outlives the temp frame
	fmt.printfln(
		"scriptgen: yielded: %s (%s — the hand-written proc of that name wins)",
		name,
		what,
	)
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
	id:           string, // "<dir>|<name>" — stable identity for cycle detection
	dir:          string, // the package dir this struct lives in (bare-name resolution)
	name:         string,
	loc:          Loc,
	packed:       bool, // `struct #packed`: no implicit ABI padding between raw wire fields
	custom_align: bool, // #align/#min_field_align/#max_field_align are target-layout policy
	input_decl:   bool, // @(gd_input): its gd field tags are input admission rules
	input_config: string, // retained so a valued marker gets a precise diagnostic
	input_loc:    Loc,
	fields:       []Struct_Field,
	imports:      map[string]string, // defining file's EXPLICIT-alias imports (alias -> "godot:kit/combat")
	poly_params:  []string, // generic parameter names ("$S" stripped to "S"), in order; nil = not generic
	// @(gd_command) procs whose FIRST param is `^<this struct>` (verb-composition), and
	// @(gd_method)/@(gd_rpc) procs likewise (method-composition). An entity that embeds this struct
	// hoists these onto its own command / method tables (recurse_into). Collected on demand by
	// index_pkg_dir alongside the fields. nil for a struct with none.
	commands:     []Command_Info,
	methods:      []Method_Info,
	// The block's @(gd_tick), if declared (tick-composition): INPUTLESS by
	// contract — intent flows through fields the wielder's tick writes — and
	// hoisted to run AFTER the entity's own tick, in field order.
	tick:         Block_Tick,
}

// Named non-struct types needed by the recursive wire-ABI walk. Structs retain
// their richer Struct_Def index above; this companion index supplies enum base
// widths, enum member order, distinct-type underlyings, and ordinary aliases.
Wire_Named_Kind :: enum u8 {
	Alias,
	Distinct,
	Enum,
}

Wire_Enum_Member :: struct {
	name:  string,
	value: string, // "" = implicit successor; explicit values are canonicalized text
}

Wire_Named_Def :: struct {
	id:         string,
	dir:        string,
	name:       string,
	kind:       Wire_Named_Kind,
	underlying: string, // enum base ("" = forbidden implicit width), alias/distinct target
	members:    []Wire_Enum_Member,
	imports:    map[string]string,
	loc:        Loc,
}

// A block's @(gd_tick): `proc(b: ^Block)`, optionally +owner pointer
// (scriptgen passes the embedding entity), optionally +`lane: ^ksim.Lane`
// last. No input (blocks read intent from their fields), no results
// (payloads are the entity tick's), no config (contested is the entity's
// declaration).
Block_Tick :: struct {
	proc_name:   string, // "" = the struct doesn't tick
	wants_owner: bool,
	wants_lane:  bool,
	// Why this tick can't compose ("" = it can). Set at index time, ERRORED
	// only at an embed site: the same dir holds entity ticks (inputs,
	// payloads, config — all fine for entities), which only become contract
	// violations if something tries to embed them as blocks.
	bad:         string,
}

// A block tick hoisted onto an embedding entity (recurse_into), routed into
// `&self.<path>` by the generated thunk.
Hoisted_Tick :: struct {
	path:        []string,
	pkg_alias:   string,
	pkg_path:    string,
	proc_name:   string,
	wants_owner: bool,
	wants_lane:  bool,
}

// dir -> (bare struct name -> def). The scripts package, plus any imported packages
// pulled in on demand for nested-bundle resolution.
g_pkgs: map[string]map[string]Struct_Def
g_wire_named: map[string]map[string]Wire_Named_Def
g_wire_codec_sizes: map[string]map[string]int
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
	named := make(map[string]Wire_Named_Def)
	codecs := make(map[string]int)
	defer {
		g_pkgs[dir] = pkg
		g_wire_named[dir] = named
		g_wire_codec_sizes[dir] = codecs
	}
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
	ticks := make(map[string]Block_Tick)
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
			if st, is_struct := vd.values[0].derived.(^ast.Struct_Type);
			   is_struct && st.fields != nil {
				name_ident, _ := vd.names[0].derived.(^ast.Ident)
				if name_ident == nil {continue}
				input_config, _ := attr_value(vd, "gd_input")
				pkg[name_ident.name] = build_struct_def(
					dir,
					fi.fullpath,
					name_ident.name,
					st,
					src,
					alias,
					imports,
					has_attr(vd, "gd_input"),
					input_config,
					name_ident.pos.line,
				)
				continue
			}
			name_ident, _ := vd.names[0].derived.(^ast.Ident)
			if name_ident == nil {continue}
			loc := Loc{fi.fullpath, name_ident.pos.line}
			if et, is_enum := vd.values[0].derived.(^ast.Enum_Type); is_enum {
				members := make([dynamic]Wire_Enum_Member)
				for elem in et.fields {
					if fv, valued := elem.derived.(^ast.Field_Value); valued {
						append(
							&members,
							Wire_Enum_Member {
								name = strings.trim_space(node_text(src, fv.field)),
								value = wire_compact_expr(node_text(src, fv.value)),
							},
						)
					} else {
						append(
							&members,
							Wire_Enum_Member{name = strings.trim_space(node_text(src, elem))},
						)
					}
				}
				base := ""
				if et.base_type != nil {
					base = normalize_godot_qualifier(node_text(src, et.base_type), alias)
				}
				named[name_ident.name] = Wire_Named_Def {
					id         = strings.concatenate({dir, "|", name_ident.name}),
					dir        = dir,
					name       = name_ident.name,
					kind       = .Enum,
					underlying = base,
					members    = members[:],
					imports    = imports,
					loc        = loc,
				}
				continue
			}
			if dt, is_distinct := vd.values[0].derived.(^ast.Distinct_Type); is_distinct {
				named[name_ident.name] = Wire_Named_Def {
					id         = strings.concatenate({dir, "|", name_ident.name}),
					dir        = dir,
					name       = name_ident.name,
					kind       = .Distinct,
					underlying = normalize_godot_qualifier(node_text(src, dt.type), alias),
					imports    = imports,
					loc        = loc,
				}
				continue
			}
			if lit, is_lit := vd.values[0].derived.(^ast.Comp_Lit); is_lit && lit.type != nil {
				lt := strings.trim_space(node_text(src, lit.type))
				if strings.has_suffix(lt, ".Wire_Codec") || lt == "Wire_Codec" {
					for elem in lit.elems {
						fv, valued := elem.derived.(^ast.Field_Value)
						if !valued ||
						   strings.trim_space(node_text(src, fv.field)) != "size" {continue}
						if n, nok := strconv.parse_int(
							strings.trim_space(node_text(src, fv.value)),
						); nok && n > 0 {
							codecs[name_ident.name] = n
						}
					}
					continue
				}
			}
			// verb-/method-composition: a bound proc on a struct in THIS package (first param
			// `^Name`, or `^Name($S)` for a generic block) — index it under that struct so an
			// embedding entity can hoist it. Same receiver rule scan_bound_procs uses for entities;
			// build_* report contract violations loudly, so a block's verbs/methods are validated
			// when a game first imports the package.
			pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
			if !is_proc {
				// Ordinary aliases are resolved only if a network declaration reaches
				// them. Indexing a same-shaped constant is harmless: using it as a type
				// will fail recursively with the declaration path that reached it.
				named[name_ident.name] = Wire_Named_Def {
					id         = strings.concatenate({dir, "|", name_ident.name}),
					dir        = dir,
					name       = name_ident.name,
					kind       = .Alias,
					underlying = normalize_godot_qualifier(node_text(src, vd.values[0]), alias),
					imports    = imports,
					loc        = loc,
				}
				continue
			}
			pt := pl.type
			if pt == nil || pt.params == nil || len(pt.params.list) == 0 {continue}
			recv := strings.trim_space(node_text(src, pt.params.list[0].type))
			if !strings.has_prefix(recv, "^") {continue}
			base := strings.trim_space(recv[1:])
			if paren := strings.index_byte(base, '(');
			   paren >= 0 {base = strings.trim_space(base[:paren])}
			if has_attr(vd, "gd_command") {
				config := command_config(vd, src)
				if ci, cok := build_command_info(
					src,
					pt,
					loc,
					name_ident.name,
					base,
					config,
					true,
				); cok {
					arr := cmds[base]
					append(&arr, ci)
					cmds[base] = arr
				}
				continue
			}
			if has_attr(vd, "gd_tick") {
				config, _ := attr_value(vd, "gd_tick")
				bt := build_block_tick(src, pt, name_ident.name, config)
				if prev, dup := ticks[base]; dup {
					bt.bad = fmt.tprintf(
						"declares two @(gd_tick) procs (%s and %s) — one tick per block",
						prev.proc_name,
						name_ident.name,
					)
				}
				ticks[base] = bt
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
	for name, bt in ticks {
		if def, dok := pkg[name]; dok {
			def.tick = bt
			pkg[name] = def
		}
	}
}

// Classify a @(gd_tick) as a COMPOSABLE block tick. The contract is TIGHTER
// than an entity's: no input (blocks read intent from their own fields; the
// input struct belongs to the avatar), no results (payloads are the entity
// tick's), no config (contested is the entity's declaration). Allowed after
// the receiver: an owner pointer (the embedding entity — scriptgen passes
// `self`), then optionally `lane: ^ksim.Lane` last. A violation is recorded
// in `bad`, NOT errored — the same dir holds entity ticks, and their richer
// shapes only become violations if something embeds them.
build_block_tick :: proc(
	src: string,
	pt: ^ast.Proc_Type,
	proc_name, config: string,
) -> Block_Tick {
	bt := Block_Tick {
		proc_name = proc_name,
	}
	if strings.trim_space(config) != "" {
		bt.bad = fmt.tprintf(
			"%s declares config %q — `contested` (and any future config) is the EMBEDDING entity's declaration, not the block's",
			proc_name,
			config,
		)
		return bt
	}
	if pt.results != nil && len(pt.results.list) > 0 {
		bt.bad = fmt.tprintf(
			"%s returns a value — payloads and their _then/_fx halves belong to the entity's own tick",
			proc_name,
		)
		return bt
	}
	types := make([dynamic]string, context.temp_allocator)
	for f in pt.params.list[1:] {
		t := strings.trim_space(node_text(src, f.type))
		for _ in 0 ..< max(1, len(f.names)) {
			append(&types, t)
		}
	}
	for text, i in types {
		if !strings.has_prefix(text, "^") {
			bt.bad = fmt.tprintf(
				"%s takes value param %q — block ticks are INPUTLESS; intent flows through fields the wielder's tick writes",
				proc_name,
				text,
			)
			return bt
		}
		base := text[1:]
		if j := strings.last_index(base, "."); j >= 0 {base = base[j + 1:]}
		if base == "Lane" {
			if bt.wants_lane || i != len(types) - 1 {
				bt.bad = fmt.tprintf("%s: the lane param comes last, once", proc_name)
				return bt
			}
			bt.wants_lane = true
		} else {
			if bt.wants_owner || bt.wants_lane {
				bt.bad = fmt.tprintf(
					"%s: unsupported param %q — the composable shape is (block[, owner][, lane: ^ksim.Lane])",
					proc_name,
					text,
				)
				return bt
			}
			bt.wants_owner = true
		}
	}
	return bt
}

@(private = "file")
build_struct_def :: proc(
	dir, path, name: string,
	st: ^ast.Struct_Type,
	src, alias: string,
	imports: map[string]string,
	input_decl: bool,
	input_config: string,
	input_line: int,
) -> Struct_Def {
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
		name = name,
		loc = Loc{path, input_line},
		packed = st.is_packed,
		custom_align = st.align != nil || st.min_field_align != nil || st.max_field_align != nil,
		input_decl = input_decl,
		input_config = input_config,
		input_loc = Loc{path, input_line},
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
			if !dok {
				// A BARE import of a SHARED package (`import "../shared/ids"`): bind its
				// package name so a `using x: ids.Bundle` embed is seen by the
				// unresolved-embed trap and refused with the shared-tree limitation,
				// instead of vanishing silently. Other relative imports stay out of the
				// map, exactly as before.
				if sdir, sok := shared_import_dir(file, full); sok {
					name = package_name_of(sdir)
					if name == "" {continue}
					m[name] = full
					continue
				}
				continue
			}
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

// Resolve an indexed type import. The normal collection form goes through the
// configured godot: root; relative imports are admitted only for the verified
// read-only shared vocabulary tree (collect_file_imports records those).
resolve_index_import_dir :: proc(from_dir, imp: string) -> (string, bool) {
	if dir, ok := resolve_import_dir(imp); ok {return dir, true}
	if strings.contains_rune(imp, ':') {return "", false}
	dir := resolve_lexical(from_dir, imp)
	if under_shared(dir) {return dir, true}
	return "", false
}

// resolve_type resolves a field's type text (seen inside `from`, and already substituted
// for any outer generic params) to a struct def, plus a substitution map for its OWN
// generic parameters. A generic instantiation `Machine(Gun_State)` resolves the base
// `Machine` and zips its params to the args (`{S = "Gun_State"}`); a plain name resolves
// via lookup_struct with an empty substitution. ok=false for non-structs / pointers /
// arrays / unresolved names — the caller skips recursion (nested-replicate-fields generics).
resolve_type :: proc(
	from: Struct_Def,
	type_text: string,
) -> (
	Struct_Def,
	map[string]string,
	bool,
) {
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

	// Schema invariant, corpus-independent: every field token has a dispatch
	// policy at every site. Run first, so a toolchain that grew a token without
	// its policy rows fails here — naming the gap — rather than on the first game
	// field that happens to use it.
	check_field_policy()

	// The project's shared vocabulary tree (`<project>/shared`), derived structurally
	// from the module root — the one place outside this module a file here may import.
	// Set BEFORE check_tree, which classifies every import against it.
	g_shared_root = shared_root_of(scripts_dir)

	// Structural whole-tree pass (helpers in subdirectories included) BEFORE the emit
	// loop: module-isolation import checks are hard errors even in files the emit loop
	// never parses, and a SUBPACKAGE importing the module root is pre-empted there with
	// a teaching error instead of Odin's raw import-cycle report inside generated code.
	// See check_tree.
	check_tree(scripts_dir)

	// The shared packages check_tree just saw imported must hold no state (and no
	// scripts, and no imports back into a module) — the condition the exemption rests
	// on. Transitive: a shared package importing a sibling shared package is checked
	// too. See scriptgen/shared.odin.
	verify_shared_tree()

	// THE MODULE TREE. The root dir is a package; so is every subdirectory holding
	// authored `.odin` sources (Odin: one directory, one package). Each is run through
	// the SAME per-dir pipeline in `process_pkg_dir` — a subdir with annotated scripts
	// gets its own consolidated `odin_godot_scripts.gen.odin`, one without gets nothing.
	// The root goes FIRST: it settles the module's package name and its hand-written-boot
	// status, which the tree-wide artifacts below need.
	pkg_dirs := discover_pkg_dirs(scripts_dir)

	// BEFORE any of that: the subpackage kit refusal, and the module-wide census of which
	// struct lives in which subfolder that the root's resolve passes word their errors
	// with. See prescan_subpkg_kit — a kit declaration in a subfolder is the ROOT CAUSE of
	// everything the root would otherwise complain about first.
	prescan_subpkg_kit(scripts_dir, pkg_dirs)

	ctx := Module_Ctx {
		root         = scripts_dir,
		seen_classes = make(map[string]string),
		pkg_names    = make(map[string]string),
		owned_gen    = make(map[string]bool),
	}
	for d, i in pkg_dirs {
		process_pkg_dir(&ctx, d, i == 0)
	}

	// The wire contract hash, over the whole tree — see module_fingerprint. Before the
	// write phase: its own toolchain-drift check can fail the build, and a failing build
	// leaves nothing on disk.
	module_fingerprint(&ctx)

	// Nothing lands on disk until the WHOLE TREE has validated. Each package's artifact
	// is written whole, and the guard's `#load_hash` set now spans every package, so one
	// bad script anywhere must not leave a half-fresh mix of today's and yesterday's
	// generated code behind — the guard would then blame whichever file it noticed first.
	if !had_error {
		for out in ctx.outputs {
			write_pkg_output(&ctx, out)
		}
	}

	// Generate the STALENESS GUARD: one compile-time `#load_hash` assert per
	// authored source ANYWHERE in the module tree (subpackage entries are named by
	// their root-relative path, which is what `#load_hash` resolves against the
	// guard file's own directory), so a build that skipped scriptgen — a bare
	// `odin build` against stale *.gen.odin — fails AT COMPILE TIME naming the
	// drifted file, instead of compiling yesterday's descriptors over today's
	// structs. The guard also carries the IMPORT MANIFEST: one blank side-effect
	// import per annotated subpackage, without which that subpackage never links
	// and its generated `@(init)` registration never runs.
	if !had_error && ctx.root_pkg != "" && len(ctx.tree_files) > 0 {
		dir := strings.trim_suffix(strings.trim_suffix(scripts_dir, "/"), "\\")
		guard_path := strings.concatenate({dir, "/odin_godot_guard.gen.odin"})
		ctx.owned_gen[norm_path(guard_path)] = true
		guard := gen_guard(
			ctx.root_pkg,
			ctx.tree_files[:],
			ctx.fingerprint,
			ctx.abi_fingerprint,
			ctx.abi_schema,
			&ctx.abi_metadata,
			ctx.kit_wire,
			ctx.sub_imports[:],
		)
		if werr := os.write_entire_file(guard_path, transmute([]byte)guard); werr != nil {
			errorf("cannot write %q", guard_path)
		} else {
			fmt.printfln("scriptgen: wrote %s (staleness guard + fingerprint)", guard_path)
		}
	}

	// Generate the REQUIRED boot shim (the `odin_scripts_boot` export the core calls after
	// dlopen) so users never hand-copy it — UNLESS the project already defines its own.
	// Skipped when the package has no name (nothing to compile anyway). ROOT ONLY: the
	// export is one per dll, and every subpackage links into the same one.
	if !had_error && !ctx.has_boot && ctx.root_pkg != "" {
		dir := strings.trim_suffix(strings.trim_suffix(scripts_dir, "/"), "\\")
		boot_path := strings.concatenate({dir, "/odin_godot_boot.gen.odin"})
		ctx.owned_gen[norm_path(boot_path)] = true
		if werr := os.write_entire_file(boot_path, transmute([]byte)gen_boot(ctx.root_pkg));
		   werr != nil {
			errorf("cannot write %q", boot_path)
		} else {
			fmt.printfln("scriptgen: wrote %s (boot shim)", boot_path)
		}
	}

	if had_error {
		os.exit(1)
	}

	// Orphan cleanup, WHOLE TREE: delete any `*.gen.odin` under the module root that this
	// run does not own — the run owns one consolidated artifact per annotated package dir
	// plus the root's guard and boot shim. That sweeps a hand-written boot's replaced
	// shim, a subpackage whose last annotated script was deleted or demoted to a helper,
	// AND it is the whole migration story for a project built before consolidation: its
	// per-source `<name>.gen.odin` files are simply unowned on the next run and go. The
	// sweep recurses because a dir can be left holding ONLY generated files, and the
	// editor's deletion probe (core/reload.odin orphans_hash_dir) recurses too — an
	// orphan it can see and scriptgen cannot would be a rebuild loop. Only on a CLEAN
	// run — after an error nothing was emitted, so nothing is collected.
	remove_orphan_gen_tree(scripts_dir, ctx.owned_gen)

	fmt.printfln("scriptgen: generated %d script(s)", ctx.emitted)
}

// ---------------------------------------------------------------------------
// The module tree
// ---------------------------------------------------------------------------

// Cross-package state for ONE module: what the per-dir pipeline contributes upward and
// what the tree-wide artifacts (guard, boot, orphan sweep) read back down.
Module_Ctx :: struct {
	root:            string, // absolute module root dir (res://scripts or res://modules/<name>)
	root_pkg:        string, // the ROOT package's `package` name — guard + boot are emitted in it
	has_boot:        bool, // the module hand-writes `odin_scripts_boot` — don't generate one
	emitted:         int, // script sections written across the whole tree
	fingerprint:     u64, // the module's wire contract hash (root scripts; kit lives there)
	abi_fingerprint: u64, // hash of abi_schema alone (diagnostics/fixtures)
	abi_schema:      string, // canonical recursive metadata emitted into the root guard
	abi_metadata:    Wire_ABI_Metadata, // same walk, structured for generated NET_SCHEMA
	kit_wire:        bool, // the root declares a kit wire surface — register the fingerprint
	// //gd:class name -> declaring file, MODULE-WIDE. The runtime registry is keyed by
	// name alone and keeps the first registration, so a root class and a subpackage class
	// of the same name would silently drop one.
	seen_classes:    map[string]string,
	// package name -> declaring dir, MODULE-WIDE. Web export links every package into ONE
	// wasm side module, where package name IS the symbol prefix.
	pkg_names:       map[string]string,
	// Root-relative dirs of the ANNOTATED subpackages, in discovery (sorted) order — the
	// guard's import manifest.
	sub_imports:     [dynamic]string,
	// One entry per package dir with annotated scripts, held until the whole tree has
	// validated (see the write phase in main).
	outputs:         [dynamic]Pkg_Output,
	// Every authored source in the tree, path-relative to the root: the guard hashes all
	// of them, so an edit in a subpackage is just as staleness-checked as one in the root.
	tree_files:      [dynamic]Helper,
	// Every gen file this run owns, tree-wide, keyed by NORMALIZED absolute path.
	owned_gen:       map[string]bool,
}

// One package dir's pending artifact: everything needed to write its consolidated
// `odin_godot_scripts.gen.odin`, resolved and validated but not yet on disk.
Pkg_Output :: struct {
	dir:      string, // absolute package dir
	rel:      string, // root-relative dir ("" = the module root)
	pkg:      string, // the Odin package name the file declares
	is_root:  bool,
	sections: []Gen_Section,
}

// write_pkg_output — emit one package's consolidated artifact and, for a subpackage,
// enrol it in the root guard's import manifest.
write_pkg_output :: proc(ctx: ^Module_Ctx, out: Pkg_Output) {
	scripts_gen := strings.concatenate(
		{strings.trim_suffix(strings.trim_suffix(out.dir, "/"), "\\"), "/", SCRIPTS_GEN_NAME},
	)
	ctx.owned_gen[norm_path(scripts_gen)] = true
	gen := generate_all(out.pkg, out.sections)
	// Emission itself can error (an import alias two packages both claim), and a
	// file we already know is broken must not land on disk under "DO NOT EDIT".
	if had_error {
		return // the diagnostic is already printed; main exits non-zero below
	}
	if werr := os.write_entire_file(scripts_gen, transmute([]byte)gen); werr != nil {
		errorf("cannot write %q", scripts_gen)
		return
	}
	ctx.emitted += len(out.sections)
	fmt.printfln("scriptgen: wrote %s (%d script section(s))", scripts_gen, len(out.sections))
	// An ANNOTATED subpackage joins the root guard's import manifest: its generated
	// `@(init) rt.register(...)` only runs if the package is linked, and nothing else in
	// the module has any reason to name it.
	if !out.is_root {append(&ctx.sub_imports, out.rel)}
}

// discover_pkg_dirs — the module's package dirs: the root (always, index 0) followed by
// every subdirectory holding at least one AUTHORED `.odin` source, at arbitrary depth,
// sorted by root-relative path so the run is deterministic. `.gen.odin` files do not
// count: a dir left holding only generated files is not a package, it is a sweep target.
discover_pkg_dirs :: proc(root: string) -> []string {
	out := make([dynamic]string)
	append(&out, root)
	subs := make([dynamic]string, context.temp_allocator)
	walk_pkg_dirs(root, &subs)
	slice.sort(subs[:])
	for s in subs {append(&out, s)}
	return out[:]
}

@(private = "file")
walk_pkg_dirs :: proc(dir: string, out: ^[dynamic]string) {
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return}
	for fi in files {
		if fi.type != .Directory {continue}
		if strings.has_prefix(fi.name, ".") {continue} 	// .godot and friends
		if has_authored_odin(fi.fullpath) {
			append(out, norm_path(fi.fullpath))
		}
		walk_pkg_dirs(fi.fullpath, out)
	}
}

@(private = "file")
has_authored_odin :: proc(dir: string) -> bool {
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return false}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return false}
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		return true
	}
	return false
}

// rel_to_root returns `path` relative to the module root with '/' separators ("" for the
// root itself). Both sides are normalized absolute paths by the time this is called.
rel_to_root :: proc(root, path: string) -> string {
	nroot := strings.trim_suffix(norm_path(root), "/")
	np := norm_path(path)
	if np == nroot {return ""}
	if strings.has_prefix(np, strings.concatenate({nroot, "/"}, context.temp_allocator)) {
		return np[len(nroot) + 1:]
	}
	return np
}

// process_pkg_dir — the whole per-package pipeline for ONE directory of the module tree.
// Identical work for the root and for a subpackage; the differences are named `is_root`
// below and are exactly three: the boot/guard/fingerprint bookkeeping is the root's, and
// KIT annotations are refused in a subpackage.
process_pkg_dir :: proc(ctx: ^Module_Ctx, scripts_dir: string, is_root: bool) {
	rel := rel_to_root(ctx.root, scripts_dir)

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

	pkg := "" // this dir's package name (for the generated boot); from the first source file
	has_boot := false // a hand-written `odin_scripts_boot` exists — don't generate one

	// Pass 1: parse every file in THIS dir. Script files (owner-struct) become pending
	// gen output; the rest are HELPERS, remembered for pass 2 — a class may spread its
	// bound procs across sibling files, so generation can't happen until every file
	// has been seen. Census scoping is per-package on purpose: halves, method claims and
	// bound procs for a subpackage's classes resolve against that subpackage alone.
	Pending :: struct {
		script: Script,
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
		// last-loaded win and mis-bind the other. Catch it here with both file paths. The map
		// is MODULE-WIDE, so a subpackage class colliding with a root one is caught too (the
		// runtime registry is keyed by name alone and keeps the first registration). This
		// bookkeeping runs BEFORE the had_error skip below so dup detection keeps working
		// across the remaining files even after an unrelated error.
		if prev, dup := ctx.seen_classes[script.class_name]; dup {
			error_at(
				Loc{path = path},
				"duplicate //gd:class %q (also declared in %q)",
				script.class_name,
				prev,
			)
		} else {
			ctx.seen_classes[script.class_name] = path
		}

		append(&pending, Pending{script = script})
	}

	// This dir's package name joins the module-wide uniqueness requirement: on web export
	// every package links into ONE wasm side module, where the package name IS the symbol
	// prefix, so two dirs sharing one name is a link collision waiting for the web build.
	if pkg != "" {
		if prev, dup := ctx.pkg_names[pkg]; dup {
			errorf(
				"duplicate package name %q — declared in both %q and %q; every package in a module tree needs its OWN name (on web export they all link into one wasm side module, where the package name is the symbol prefix)",
				pkg,
				prev,
				scripts_dir,
			)
		} else {
			ctx.pkg_names[pkg] = scripts_dir
		}
	}
	if is_root {
		ctx.root_pkg = pkg
		ctx.has_boot = has_boot
	} else if has_boot {
		errorf(
			"%s: `odin_scripts_boot` is declared in the subpackage %q — the boot export is ONE per dll and every subpackage links into the module's; move it to the module root (%s)",
			rel,
			rel,
			ctx.root,
		)
	}
	// The guard hashes every authored source in the TREE, named by its root-relative path.
	for l in lintable {
		append(&ctx.tree_files, Helper{path = rel_to_root(ctx.root, l.path), src = l.src})
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

	// KIT ANNOTATIONS ARE MODULE-ROOT-ONLY, checked as early as the parse allows (every
	// DECLARED kit surface is in by now — the home file's and the helpers') so the teaching
	// error arrives before whatever secondary complaint the resolve passes would make about
	// the same declaration. The stragglers that only exist after name pairing (session and
	// succession halves, world-pass facts) are caught by the second sweep further down.
	condemned := false
	if !is_root {
		for &pend in pending {
			if check_subpkg_kit(&pend.script, rel, ctx.root, early = true) {condemned = true}
		}
	}
	if condemned {return}

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
	half_idx := make(map[string]Half_Candidate)
	defer delete(half_idx)
	method_claims := make([dynamic]Method_Claim)
	defer delete(method_claims)
	cmd_calls := make([dynamic]Cmd_Call)
	defer delete(cmd_calls)
	proc_names := make(map[string]Proc_Site)
	defer delete(proc_names)
	fact_decls := make([dynamic]Fact_Candidate)
	defer delete(fact_decls)
	for l in lintable {
		file := ast.File {
			fullpath = l.path,
			src      = l.src,
		}
		p := parser.default_parser()
		p.err = silent_parse_diag
		p.warn = silent_parse_diag
		if !parser.parse_file(&p, &file) {continue}
		scan_half_procs(&half_idx, l.path, l.src, &file)
		scan_method_claims(&method_claims, l.path, l.src, &file, script_structs)
		scan_command_calls(&cmd_calls, l.path, l.src, &file)
		scan_proc_names(&proc_names, l.path, &file)
		scan_fact_procs(&fact_decls, l.path, l.src, &file)
		lint_attributed_receivers(l.path, l.src, &file, script_structs)
	}
	by_struct := make(map[string]^Script)
	defer delete(by_struct)
	for &pend in pending {
		by_struct[pend.script.struct_name] = &pend.script
	}
	seen_entity_ids := make(map[int]string)
	defer delete(seen_entity_ids)
	for &pend in pending {
		// `proc_names` rides along beside the half index: each pass looks a
		// computed name up in the halves, and on a miss asks whether a proc by
		// that exact name exists anyway — a half that was written and never
		// declared itself (demand_half). Threaded, never a package global, so
		// the passes stay callable in any order and testable one at a time.
		resolve_then(&pend.script, &half_idx, proc_names)
		resolve_tick_then(&pend.script, &half_idx, proc_names)
		resolve_edges(&pend.script, &half_idx, proc_names)
		resolve_session_events(&pend.script, &half_idx, proc_names)
		resolve_migration(&pend.script, &half_idx, proc_names)
		resolve_command_applies(&pend.script, &half_idx, proc_names)
		validate_command_ids(&pend.script)
		resolve_entities(&pend.script, by_struct, &seen_entity_ids, &half_idx, proc_names)
		resolve_onready_scripts(&pend.script, by_struct)
		resolve_census(&pend.script, proc_names)
		resolve_probes(&pend.script, by_struct, proc_names)
		resolve_boot_forwards(&pend.script)
		resolve_profile(&pend.script, scripts_dir)
		// Last: the probes and forwards above APPEND methods (after yielding to
		// any hand-written name), so the generated-name collision check has to
		// see the finished table.
		validate_method_names(&pend.script)
	}
	{
		// The lane's module-wide contracts: one input struct, one wired class.
		all := make([dynamic]^Script, context.temp_allocator)
		for &pend in pending {append(&all, &pend.script)}
		resolve_sim(all[:])
		// Declared world-pass facts land on the lane owner resolve_sim just
		// settled.
		resolve_facts(all[:], fact_decls[:], by_struct, proc_names)
		// With the lane owner now known, conventional game shells get the
		// generated attach/pump/detach facade. (A multi-session shell stays on
		// the explicit lower-level API; there is no safe field to guess.)
		for s in all {
			resolve_net_facade(s, proc_names)
		}
		// Last, with every pass's claims in: the halves that paired with
		// nothing. Needs the whole script list, not just by_struct — the fix
		// it prints is each target class's real pairing surface, and an
		// entity's `_spawned`/`_freed` names are declared on a DIFFERENT class
		// (whichever one carries the scene's `entity=` tag).
		check_unpaired_halves(&half_idx, all[:], by_struct)
	}
	lint_method_claims(method_claims[:], by_struct)
	{
		// THE RAW-VERB lint: every command set is complete now (composed verbs
		// hoisted), so a direct call of a @(gd_command) proc names itself.
		all := make([dynamic]^Script, 0, len(pending), context.temp_allocator)
		for &pend in pending {append(&all, &pend.script)}
		lint_command_calls(cmd_calls[:], all[:])
	}

	// The SECOND kit sweep: the surfaces that only exist after name pairing — session
	// and succession halves, world-pass facts, the boot transport forwards. Everything
	// they need was resolved just above, so a subpackage that paired one is named now.
	if !is_root {
		if len(fact_decls) > 0 {
			error_at(
				Loc{path = fact_decls[0].path},
				"@(%s) in the script subpackage %q — %s",
				fact_decls[0].attr,
				rel,
				subpkg_kit_fix(rel, ctx.root),
			)
			return
		}
		for &pend in pending {
			if check_subpkg_kit(&pend.script, rel, ctx.root, early = false) {condemned = true}
		}
		if condemned {return}
	}

	// Generate, now that every file's contribution is in (validation too — a
	// @(gd_command) found in a helper still needs its class's replicate/net_id).
	//
	// ONE artifact per package dir. Validate EVERY script first: the file is written
	// whole, so a single bad script must not leave a half-fresh mix of today's and
	// yesterday's sections behind (the staleness guard would then blame the wrong file).
	for &pend in pending {
		validate_script(&pend.script)
	}
	if !had_error && len(pending) > 0 {
		// Sections in source-filename order — deterministic output for the same
		// inputs, whatever order the directory listing handed the files over. Queued,
		// not written: main writes every package's artifact once the tree has validated.
		sections := make([dynamic]Gen_Section, 0, len(pending))
		for &pend in pending {
			append(
				&sections,
				Gen_Section{src_name = path_base(pend.script.path), script = &pend.script},
			)
		}
		slice.sort_by(
			sections[:],
			proc(a, b: Gen_Section) -> bool {return a.src_name < b.src_name},
		)
		append(
			&ctx.outputs,
			Pkg_Output {
				dir = scripts_dir,
				rel = rel,
				pkg = pending[0].script.pkg,
				is_root = is_root,
				sections = sections[:],
			},
		)
	}
}

// module_fingerprint — the module's WIRE CONTRACT hash, and whether it has one at all.
//
// Runs once over the WHOLE TREE, after every package dir has been processed and before
// anything is written (check_fingerprint_contrib can fail the build, and a failing build
// writes nothing). It cannot live in the root's own pass: the root is processed FIRST, and
// this needs the subpackages' class names.
//
// WHY SUBPACKAGE CLASS NAMES FOLD IN. The kit surface is root-only by construction, so a
// subpackage class contributes no replicated field, verb, entity id or tick — only its
// NAME, which net_fingerprint writes for every class whether or not it has wire surface.
// Fold the subpackage names in beside the root's and moving a class between the root and a
// subfolder is invisible to the hash: pure organization stops being a join-door version
// break (Deny_Reason.Version) between an old build and a new one. Leaving them out is not
// an option either — then the move would be invisible in one direction and not the other.
// A FLAT module has no subpackage names, so its fingerprint is byte-identical to what
// every shipped build already computed.
module_fingerprint :: proc(ctx: ^Module_Ctx) {
	if had_error {return}
	root_scripts := make([dynamic]^Script, context.temp_allocator)
	sub_classes := make([dynamic]string, context.temp_allocator)
	for out in ctx.outputs {
		for sec in out.sections {
			if out.is_root {
				append(&root_scripts, sec.script)
			} else {
				append(&sub_classes, sec.script.struct_name)
			}
		}
	}
	root := strings.trim_suffix(strings.trim_suffix(ctx.root, "/"), "\\")
	ctx.abi_metadata = canonical_wire_abi(root_scripts[:], root)
	ctx.abi_schema = ctx.abi_metadata.canonical
	ctx.abi_fingerprint = fnv1a64(ctx.abi_schema)
	ctx.fingerprint = net_fingerprint(root_scripts[:], sub_classes[:], root, ctx.abi_schema)
	// A module with a kit wire surface registers its fingerprint as the
	// session default (guard file @(init)) — the version gate is on
	// without any game wiring. Engine-native-only modules (@(gd_rpc),
	// plain exports) skip it: no kit import, no session to gate.
	for s in root_scripts {
		if len(s.replicates) > 0 ||
		   len(s.commands) > 0 ||
		   len(s.entities) > 0 ||
		   s.tick.proc_name != "" ||
		   s.profile_type != "" ||
		   len(s.messages) > 0 {
			ctx.kit_wire = true
			break
		}
	}
}

// The ONE generated artifact per PACKAGE dir — the module root's sits beside the boot and
// guard shims it sorts with; a script subpackage's is the only generated file it holds.
// The `.gen.odin` suffix is load-bearing: the editor keys every special case off it
// — the FileSystem-dock filter hides it (core/gen_filter.odin), the loader refuses to
// attach it as a script (core/loader.odin), and the reload hash skips it (core/reload.odin).
SCRIPTS_GEN_NAME :: "odin_godot_scripts.gen.odin"

// path_base returns the last '/'- or '\'-separated segment of `p` (the filename).
path_base :: proc(p: string) -> string {
	if i := strings.last_index_any(p, "/\\"); i >= 0 {return p[i + 1:]}
	return p
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

// remove_orphan_gen_tree — the orphan sweep over a whole module tree. Every package dir
// under the root may hold generated output, and so may a dir whose last authored source
// was just deleted (which is exactly why the sweep cannot be limited to the package dirs
// this run discovered).
remove_orphan_gen_tree :: proc(dir: string, owned: map[string]bool) {
	remove_orphan_gen(dir, owned)
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return}
	for fi in files {
		if fi.type != .Directory {continue}
		if strings.has_prefix(fi.name, ".") {continue}
		remove_orphan_gen_tree(fi.fullpath, owned)
	}
}

// remove_orphan_gen deletes `*.gen.odin` files in `dir` (non-recursive) that are not in
// `owned` — a run owns one consolidated artifact per annotated package dir plus the root's
// guard and boot shim, so this collects gen output for sources that no longer exist AND
// the per-source `<name>.gen.odin` files a pre-consolidation build left behind. A Godot
// `.uid` sidecar for a removed gen file goes with it (the editor generates those beside
// every res:// file).
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
		fmt.printfln("scriptgen: removed stale %s (not generated by this run)", fi.fullpath)
		uid := strings.concatenate({fi.fullpath, ".uid"})
		if os.exists(uid) {
			os.remove(uid)
		}
	}
}

// ---------------------------------------------------------------------------
// Whole-tree structural checks (module isolation + misplaced //gd: markers)
// ---------------------------------------------------------------------------

// check_tree — one recursive pass over EVERY authored `.odin` under the scripts dir,
// before any package dir is processed:
//
//   1. IMPORT ISOLATION, all files: a script module may import collections
//      (godot:/core:/base:/vendor:), packages that RESOLVE INSIDE the module's own
//      directory (subpackages, subpackages importing each other), and packages in the
//      project's SHARED VOCABULARY tree (`<project>/shared/…`, verified state-free —
//      see shared.odin). Anything else — an absolute path, or a relative path that
//      escapes the module root after lexical normalization — is a HARD ERROR. Odin
//      itself would happily compile
//      `import "../other_module"`, but a package linked into two script dlls duplicates
//      its package GLOBALS per dll and the "shared" state silently forks. The bash/ps1
//      builds keep a fast grep for the same rule (check_module_isolation in
//      build/common.sh, ported in build/build_scripts.ps1) as a backstop; THIS is the
//      structural check that also catches absolute paths and creative spellings.
//
//   2. NO SUBPACKAGE -> ROOT IMPORT, subdirectory files only: the root's generated
//      import manifest imports every annotated subpackage, so a subpackage importing the
//      root is always a cycle. Odin would report it, but from inside DO NOT EDIT code —
//      so it is pre-empted here, teaching-style, before the manifest is even written.
//      A subpackage importing a SIBLING subpackage is a legal DAG edge and is untouched.
check_tree :: proc(scripts_dir: string) {
	check_tree_dir(scripts_dir, scripts_dir, true)
}

check_tree_dir :: proc(dir, root: string, is_top: bool) {
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return} 	// unreadable dirs are surfaced by the emit loop / odin build
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return}
	for fi in files {
		if fi.type == .Directory {
			if strings.has_prefix(fi.name, ".") {continue} 	// .godot and friends
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
	if !parser.parse_file(&p, &file) {return} 	// unparseable — odin build reports it
	file_dir := norm_path(path)
	if i := strings.last_index(file_dir, "/"); i >= 0 {
		file_dir = file_dir[:i]
	}
	for imp in file.imports {
		check_import(root, file_dir, path, imp, is_top)
	}
}

// The teaching text shared with the bash grep (check_module_isolation in build/common.sh)
// — why a cross-module import is rejected instead of merely discouraged, and the one
// tree that is exempt (see scriptgen/shared.odin).
@(private = "file")
explain_isolation :: proc() {
	fmt.eprintln("  Script modules are ISOLATED packages: a package imported by two script dlls")
	fmt.eprintln("  duplicates its globals per dll (shared state would silently fork). Talk to")
	fmt.eprintln("  other modules through the engine (signals / methods / autoloads) instead,")
	fmt.eprintln("  or move the shared state into exactly one module.")
	fmt.eprintln(
		"  For types, constants and pure procs — a vocabulary with no state to fork —",
	)
	fmt.eprintln("  put the package under res://shared/ instead: any module may import it")
	fmt.eprintln(
		"  (`import \"../shared/<pkg>\"` from res://scripts, `\"../../shared/<pkg>\"` from",
	)
	fmt.eprintln("  res://modules/<name>), and scriptgen verifies that tree stays state-free.")
}

// check_import validates ONE import declaration against the isolation rule. `root` is the
// absolute scripts dir being compiled; `file_dir` the importing file's dir (normalized);
// `is_top` says the importing file lives in the module ROOT (where importing the root is
// simply importing yourself, which Odin's own resolver handles).
check_import :: proc(root, file_dir, path: string, imp: ^ast.Import_Decl, is_top: bool) {
	ipath := strings.trim(imp.fullpath, "\"")
	loc := Loc{path, imp.pos.line}
	// `<collection>:<pkg>` — godot:/core:/base:/vendor: (an unknown collection is odin
	// build's own error). Collection imports never cross module boundaries.
	if strings.contains_rune(ipath, ':') {return}
	if strings.has_prefix(ipath, "/") || strings.has_prefix(ipath, "\\") {
		error_at(
			loc,
			"ILLEGAL cross-module import %q — absolute import paths are not allowed in a script module; import collections (godot:/core:/base:/vendor:) or packages inside this module's directory",
			ipath,
		)
		explain_isolation()
		return
	}
	nroot := norm_path(root)
	resolved := resolve_lexical(file_dir, ipath)
	// THE SHARED VOCABULARY TREE. A package under `<project>/shared/` carries no state
	// to fork (scriptgen verifies that — see shared.odin), so every module may import it,
	// from the root package or any subpackage, at any depth. Recorded here so the
	// verification pass covers exactly the shared packages that are actually reached.
	if under_shared(resolved) {
		note_shared_import(resolved, loc)
		return
	}
	if resolved != nroot && !strings.has_prefix(resolved, strings.concatenate({nroot, "/"})) {
		error_at(
			loc,
			"ILLEGAL cross-module import %q — resolves to %q, outside this script module's directory (%s)",
			ipath,
			resolved,
			nroot,
		)
		explain_isolation()
		return
	}
	// The import CYCLE the manifest makes unavoidable. Reported here, naming the fix,
	// rather than as Odin's cycle report against `odin_godot_guard.gen.odin`.
	if !is_top && resolved == nroot {
		error_at(
			loc,
			"a subfolder script package cannot import the module root (%q resolves to %s) — the root's generated import manifest already imports every script subpackage, so this is an import CYCLE",
			ipath,
			nroot,
		)
		fmt.eprintln(
			"  Subfolders hold engine-native script classes and helpers; they are LEAVES of the",
		)
		fmt.eprintln(
			"  module. Anything that needs the module root's types or state is game-coupled and",
		)
		fmt.eprintln(
			"  belongs in the module root itself. To share the other way, move the shared code",
		)
		fmt.eprintln(
			"  DOWN into a subpackage both the root and the subfolder import (sibling subpackage",
		)
		fmt.eprintln("  imports are legal), or pass what it needs in as an argument.")
	}
}

// resolve_lexical joins `rel` onto `base_dir` and normalizes `.`/`..` segments purely
// lexically (no filesystem access — symlink dodges are not a concern here, the rule is
// about what the COMPILER will resolve, and odin resolves imports lexically too).
resolve_lexical :: proc(base_dir, rel: string) -> string {
	joined := strings.concatenate(
		{norm_path(base_dir), "/", norm_path(rel)},
		context.temp_allocator,
	)
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

// ---------------------------------------------------------------------------
// Kit annotations are module-root-only
// ---------------------------------------------------------------------------
//
// A subpackage script gets the whole ENGINE-NATIVE surface — `//gd:extends`/`//gd:class`,
// methods, signals, exports, onready, rpc, lifecycles, tool/icon — everything whose
// generated code needs only `gd`/`gdext`/`rt`. What it does not get is any KIT wiring.
//
// The reason is not layering taste. A module's kit surface IS its wire contract: the
// replicated field order, the verb ids, the entity type ids, the ONE tick input struct,
// the fact tuples — all folded into NET_FINGERPRINT, which two peers compare at the join
// door. That contract is defined per MODULE, resolved package-wide (one lane owner, one
// input class table, one command id space), and it is the most game-coupled thing in a
// project. Subfolders exist for the opposite kind of code: leaf classes that a HUD or a
// tools menu attaches, which the module root may not even know about. Letting a lane, a
// verb or a replicated field hide in one would put half the wire contract somewhere the
// module-wide resolution passes deliberately cannot see — and the failure would be a
// fingerprint that silently omits it.
//
// So every kit-coupled declaration is a HARD error here, naming the SPECIFIC feature and
// the file to move. `early` selects the surfaces that are complete right after parsing
// (the common case, reported before the resolve passes can complain about the same
// declaration in their own words) from the name-paired ones that only exist afterwards.
// Returns true if anything fired.
Subpkg_Kit_Feature :: struct {
	what:    string, // the offending declaration, as the author wrote it
	early:   bool, // in by the end of pass 2 (parse + bound procs)
	present: proc(s: ^Script) -> bool,
}

SUBPKG_KIT_FEATURES := [?]Subpkg_Kit_Feature {
	{
		"a gd:\"replicate\" field tag",
		true,
		proc(s: ^Script) -> bool {return len(s.replicates) > 0},
	},
	{"a gd:\"backup\" field tag", true, proc(s: ^Script) -> bool {return len(s.backups) > 0}},
	{
		"an `entity=` scene field (the entity table)",
		true,
		proc(s: ^Script) -> bool {return len(s.entities) > 0},
	},
	{"a `net_id` field", true, proc(s: ^Script) -> bool {return s.net_id_type != ""}},
	{"a gd:\"profile=\" field tag", true, proc(s: ^Script) -> bool {return s.profile_type != ""}},
	{"a @(gd_command) proc", true, proc(s: ^Script) -> bool {return len(s.commands) > 0}},
	{"a @(gd_tick) proc", true, proc(s: ^Script) -> bool {
			return s.tick.proc_name != "" || len(s.block_ticks) > 0
		}},
	{"a @(gd_sample) proc", true, proc(s: ^Script) -> bool {return len(s.samples) > 0}},
	{"a @(gd_step) proc", true, proc(s: ^Script) -> bool {
			return s.step.proc_name != "" || s.step_auth.proc_name != ""
		}},
	{"a @(gd_message) handler", true, proc(s: ^Script) -> bool {return len(s.messages) > 0}},
	{
		"a kboot.Boot field (the standard transport forwards)",
		true,
		proc(s: ^Script) -> bool {return s.boot_field != ""},
	},
	// Name-paired: these exist only once the resolve passes have run.
	{"a session-event half", false, proc(s: ^Script) -> bool {return len(s.event_halves) > 0}},
	{"a host-migration (succession) half", false, proc(s: ^Script) -> bool {
			return(
				s.succ_backup != "" ||
				s.succ_took_over != "" ||
				s.succ_wiped != "" ||
				s.succ_migrating != "" \
			)
		}},
	{"a declared presentation cue", false, proc(s: ^Script) -> bool {return len(s.facts) > 0}},
	{
		"an input class (the sim lane's wire input)",
		false,
		proc(s: ^Script) -> bool {return len(s.input_classes) > 0},
	},
}

// The one sentence every kit-in-a-subpackage error ends with.
subpkg_kit_fix :: proc(rel, root: string) -> string {
	return fmt.tprintf(
		"kit wiring is part of the MODULE's wire contract (fingerprint, lanes, input struct) and is game-coupled; move this file to the module root (%s). Subfolders like %s/ hold engine-native script classes: extends/class, methods, signals, exports, onready, rpc",
		root,
		rel,
	)
}

check_subpkg_kit :: proc(s: ^Script, rel, root: string, early: bool) -> bool {
	fired := false
	for f in SUBPKG_KIT_FEATURES {
		if f.early != early {continue}
		if !f.present(s) {continue}
		error_at(
			Loc{path = s.path},
			"%s declares %s in the script subpackage %q — %s",
			s.struct_name,
			f.what,
			rel,
			subpkg_kit_fix(rel, root),
		)
		fired = true
	}
	// The BACKSTOP, in the toolchain's own terms: generation decides its kit imports from
	// the Script's fields (script_needs). If it would reach for one and the table above
	// named nothing, the table has a hole — say so rather than emit a subpackage file that
	// imports kit and fails to link the way the rule exists to prevent.
	if !fired && !early {
		n := script_needs(s)
		if n.knet || n.ksim || n.ksess || n.kboot || n.netgd {
			error_at(
				Loc{path = s.path},
				"%s needs a kit import in the script subpackage %q, but no kit declaration was named — %s (scriptgen bug: SUBPKG_KIT_FEATURES is missing a row)",
				s.struct_name,
				rel,
				subpkg_kit_fix(rel, root),
			)
			fired = true
		}
	}
	return fired
}

// ---- the subpackage PRE-SCAN: the root cause leads --------------------------
//
// Script struct name -> the root-relative SUBPACKAGE dir that declares it, module-wide.
// Filled by prescan_subpkg_kit before any package resolves, so a root pass that fails to
// find a name can say WHERE it went instead of "no such struct" (resolve_entities,
// check_unpaired_halves). Empty for a flat module, which is most of them.
g_subpkg_structs: map[string]string

// prescan_subpkg_kit — refuse kit declarations in a script subpackage BEFORE the module
// root resolves anything, and census the subpackages' class names on the way past.
//
// THE PROBLEM IT SOLVES. Moving one kit entity into a subfolder used to print three
// DERIVED errors before either real one: the root's `entity Zone: no script struct named
// "Zone"` (true — the entity table resolves per package), then two `@(gd_half) … pairs
// with nothing` complaints listing every half the moved class used to claim. The cause was
// the fourth thing on screen. The root is processed first for good reasons, and errors are
// printed as they are found, so no amount of care inside the per-dir pipeline can fix that
// ordering.
//
// WHY A PRE-SCAN RATHER THAN A REORDER. Processing subpackages first would reorder every
// unrelated diagnostic in the tree (a typo in a HUD would then precede a real root error),
// and it still would not SUPPRESS the derived errors — the root would resolve afterwards
// and print them anyway. This pass is surgical instead: it is speculative (diagnostics
// muted, see g_quiet_diag, so a file parsed twice never complains twice), it only asks the
// one question, and when the answer is yes it prints the refusals and exits — so the
// author sees the cause and nothing else. Nothing has been written at this point.
//
// It repeats pass 1 + pass 2 of process_pkg_dir (parse each file, then let helper files'
// bound procs join their class) because that is exactly the state `early = true` features
// are complete in. The later name-paired surfaces — session/succession halves, facts,
// input classes — still come from the real pass, which is where they first exist.
prescan_subpkg_kit :: proc(root: string, pkg_dirs: []string) {
	fired := false
	for d, i in pkg_dirs {
		if i == 0 {continue} 	// the module root: kit belongs there
		rel := rel_to_root(root, d)
		for s in prescan_pkg_scripts(d) {
			g_subpkg_structs[s.struct_name] = rel
			if check_subpkg_kit(s, rel, root, early = true) {fired = true}
		}
	}
	if fired {
		os.exit(1)
	}
}

// prescan_pkg_scripts — one package dir's script structs, parsed with diagnostics MUTED.
// The mirror of process_pkg_dir's passes 1 and 2, minus everything that reports or emits.
@(private = "file")
prescan_pkg_scripts :: proc(dir: string) -> []^Script {
	out := make([dynamic]^Script)
	dir_fh, oerr := os.open(dir)
	if oerr != nil {return out[:]}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {return out[:]}

	// Same as the real pass: index before parsing, so nested `using` bundles resolve.
	// Idempotent, so the real pass reuses this index rather than redoing it.
	index_pkg_dir(norm_path(dir))

	g_quiet_diag = true
	defer g_quiet_diag = false

	helpers := make([dynamic]Helper)
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		src_bytes, rerr := os.read_entire_file_from_path(fi.fullpath, context.allocator)
		if rerr != nil {continue}
		src := string(src_bytes)
		script, has := parse_script(fi.fullpath, src)
		if !has {
			append(&helpers, Helper{path = fi.fullpath, src = src})
			continue
		}
		append(&out, new_clone(script))
	}
	for h in helpers {
		file := ast.File {
			fullpath = h.path,
			src      = h.src,
		}
		p := parser.default_parser()
		p.err = silent_parse_diag
		p.warn = silent_parse_diag
		if !parser.parse_file(&p, &file) {continue}
		for s in out {
			scan_bound_procs(s, h.path, h.src, &file)
		}
	}
	return out[:]
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

// One authored package file (path + contents) — scripts and helpers both; the
// per-dir pass collects them and the staleness guard hashes them.
Helper :: struct {
	path: string,
	src:  string,
}

@(private = "file")
fnv1a64 :: proc(s: string) -> u64 {
	return decl.fnv1a64(s) // the shared hash law — godot:decl states the namespaces
}

// The package's WIRE CONTRACT, hashed: everything two builds must agree on to
// parse each other's packets — the recursive canonical ABI (paths, exact
// representations, widths, bounds, policies, and scheduling), entity type ids,
// broadcast fact tuples, and @(gd_rpc) signatures. Deliberately
// EXCLUDED (local behavior, not wire): interp/lerp/blend, slack/glide/cut,
// gd:"backup" (host-local saves), methods/signals/exports, world passes.
// Field NAMES are hashed too — a rename over-refuses a join (annoying,
// harmless: rebuild both ends); a type change under-refusing would be the
// silent-garbage disaster the fingerprint exists to prevent. The session
// folds its own PROTOCOL_REV in before the wire, so kit upgrades refuse too.
// `gd:"profile=Type"`'s module contract: the row type must exist beside the
// game (the fingerprint hashes its fields; a name that resolves to nothing
// would silently hash to nothing), and the class needs a ready — the
// generated install lives in the ready thunk.
resolve_profile :: proc(s: ^Script, scripts_dir: string) {
	if s.profile_type == "" {
		return
	}
	has_ready := false
	for lc in s.lifecycles {
		if lc.keyword == "ready" {has_ready = true; break}
	}
	if !has_ready {
		errorf(
			"%s: gd:\"profile=%s\" needs a `%s_ready` — the generated session_profile_install is wired into the ready thunk",
			s.struct_name,
			s.profile_type,
			to_snake(s.struct_name),
		)
	}
	dir := strings.trim_suffix(strings.trim_suffix(scripts_dir, "/"), "\\")
	index_pkg_dir(dir)
	if pkg, ok := g_pkgs[dir]; ok {
		if _, has := pkg[s.profile_type]; !has {
			errorf(
				"%s: gd:\"profile=%s\" — no struct %q in this package (the row type lives beside the game; it is POD, ≤ ksess.PROFILE_MAX_SIZE)",
				s.struct_name,
				s.profile_type,
				s.profile_type,
			)
		}
	}
}

// ---- the per-context policy column, kept honest -----------------------------
//
// decl.FIELD_POLICY says, per token per site, whether the shared dispatch
// handles / refuses / defers-to-caller a leading tag token. walk_tagged_field
// CONSULTS it, so a hole in the table is not a documentation gap — it is a
// missing switch arm that would `assert(has)` at parse time on some field a game
// actually wrote. This turns the hole into a build error BEFORE any corpus is
// read, naming the token and the site, exactly as check_fingerprint_contrib does
// for the fingerprint column: every FIELD_TOKENS token needs a row at BOTH sites,
// a Refuse row must carry its reason, and a non-Refuse row must not (a stray
// reason is a refusal someone wrote and the action forgot).
check_field_policy :: proc() {
	for t in decl.FIELD_TOKENS {
		for site in decl.Field_Site {
			pol, has := decl.field_policy(t.name, site)
			if !has {
				errorf(
					"decl.FIELD_TOKENS has `%s` and decl.FIELD_POLICY has no row for it at site %v — add one saying whether the shared dispatch handles, refuses, or defers-to-caller a leading `%s` there (a hole would assert at parse time on the first field that uses it)",
					t.name,
					site,
					t.name,
				)
				continue
			}
			switch pol.action {
			case .Refuse:
				if pol.reason == "" {
					errorf(
						"decl.FIELD_POLICY refuses `%s` at %v but gives no reason — the dispatch prints it verbatim, so an empty one is a blank error",
						t.name,
						site,
					)
				}
			case .Handle, .Caller:
				if pol.reason != "" {
					errorf(
						"decl.FIELD_POLICY row for `%s` at %v is %v but carries a reason string — reasons are for Refuse only (a refusal someone wrote and the action forgot?)",
						t.name,
						site,
						pol.action,
					)
				}
			}
		}
	}
}

// ---- the fingerprint column, made load-bearing ------------------------------
//
// decl.FIELD_TOKENS carries a `fingerprint: bool` per token, and it was written
// to DOCUMENT which declarations fold into NET_FINGERPRINT. Nothing read it, and
// a documentation column beside a hand-written serializer drifts the way every
// other list in this toolchain drifted before it got projected — except that
// THIS drift has no symptom. A token marked true that net_fingerprint forgets is
// a wire declaration outside the version door: two builds that disagree about it
// hash identically, shake hands, and misparse each other's packets for the rest
// of the session. That is the exact failure the fingerprint exists to prevent,
// arriving through the fingerprint's own bookkeeping.
//
// It had already drifted. `backup` shipped as fingerprint = true and contributes
// nothing here — correctly, as it turns out (see the column's comment in
// decl/decl.odin: a save has its own fnv1a32 format stamp and is refused at the
// LOAD door, not the join door), so the fix was the column, not the serializer.
// Nothing was going to notice on its own.
//
// The serializer cannot be DRIVEN from the table: every contributor has its own
// shape (`rep path:type owner=…`, `entity Name=id`, `profile T.f:type`) and
// pushing those into decl would move wire semantics into a package whose entire
// point is that it is small enough to read. So the table drives a CHECK instead,
// in both directions a row can be wrong:
//
//   * every token needs a row here — a new one does not get to be silently
//     assumed wire-irrelevant;
//   * a row's marker is non-empty exactly when decl says the token is a
//     fingerprint input;
//   * and if the corpus DECLARES such a token, the serialized string must
//     actually carry its marker — which is what catches a serializer arm that
//     gets deleted, reordered into a dead branch, or never written.
@(private = "file")
Fingerprint_Contrib :: struct {
	token:    string, // a decl.FIELD_TOKENS name, verbatim
	marker:   string, // the line prefix net_fingerprint writes for it ("" = contributes nothing)
	declared: proc(s: ^Script, scripts_dir: string) -> bool, // nil for non-contributors
}

@(private = "file")
FINGERPRINT_CONTRIB := [?]Fingerprint_Contrib {
	// Editor dressing and node wiring: local presentation, never bytes on a wire.
	{"export", "", nil},
	{"onready=", "", nil},
	// The three lanes all serialize as `rep` lines — one marker, three tokens,
	// because the lane rides IN the line (`owner=%v predict=%v`) rather than
	// choosing a different one.
	{"replicate", "rep ", proc(s: ^Script, _: string) -> bool {
			for r in s.replicates {if !r.owner && !r.predict {return true}}
			return false
		}},
	{"owner", "rep ", proc(s: ^Script, _: string) -> bool {
			for r in s.replicates {if r.owner {return true}}
			return false
		}},
	{"predict", "rep ", proc(s: ^Script, _: string) -> bool {
			for r in s.replicates {if r.predict {return true}}
			return false
		}},
	// Host-local save state. Guarded by the backup codec's OWN fnv1a32 stamp at
	// the load door — a drifted save is refused there, and refusing the JOIN over
	// it would ground peers whose save files were never going to meet.
	{"backup", "", nil},
	{"manual", "", nil},
	// The row IS the wire bytes, field by field — but only if it resolved and has
	// any. An unresolvable row type is already a hard error in resolve_profile and
	// an empty struct genuinely contributes nothing, so the witness asks the same
	// question the serializer does rather than a looser one that would refuse a
	// build for a hole that isn't there.
	{"profile=", "profile ", proc(s: ^Script, dir: string) -> bool {
			if s.profile_type == "" {return false}
			pkg, ok := g_pkgs[dir]
			if !ok {return false}
			def, has := pkg[s.profile_type]
			return has && len(def.fields) > 0
		}},
	{"entity=", "entity ", proc(s: ^Script, _: string) -> bool {return len(s.entities) > 0}},
	{"args=", "", nil}, // a signal's parameter NAMES — engine-side, never wire
}

// Checks FINGERPRINT_CONTRIB against decl.FIELD_TOKENS and then against what the
// serializer actually wrote. `text` is the exact string about to be hashed.
@(private = "file")
check_fingerprint_contrib :: proc(scripts: []^Script, scripts_dir: string, text: string) {
	for t in decl.FIELD_TOKENS {
		row: Fingerprint_Contrib
		found := false
		for c in FINGERPRINT_CONTRIB {
			if c.token == t.name {
				row = c
				found = true
				break
			}
		}
		if !found {
			errorf(
				"decl.FIELD_TOKENS has `%s` and scriptgen's FINGERPRINT_CONTRIB has no row for it — add one saying which line net_fingerprint writes for it, or \"\" if it is not a wire declaration",
				t.name,
			)
			continue
		}
		contributes := row.marker != ""
		if contributes != t.fingerprint {
			if t.fingerprint {
				errorf(
					"decl.FIELD_TOKENS marks `%s` a NET_FINGERPRINT input and net_fingerprint writes nothing for it — serialize it here, or clear the column (a wire declaration outside the version door hashes the same on both builds and misparses past the handshake)",
					t.name,
				)
			} else {
				errorf(
					"scriptgen's FINGERPRINT_CONTRIB says `%s` reaches the fingerprint and decl.FIELD_TOKENS says it does not — set the column, or drop the marker",
					t.name,
				)
			}
			continue
		}
		if !contributes || had_error {
			continue // nothing to witness, or the build is already failing for a realer reason
		}
		declared := false
		for s in scripts {
			if row.declared != nil && row.declared(s, scripts_dir) {
				declared = true
				break
			}
		}
		if declared && !strings.contains(text, row.marker) {
			errorf(
				"this build declares `%s` and net_fingerprint wrote no %q line for it — the declaration crosses the wire and would not be checked at the join door",
				t.name,
				row.marker,
			)
		}
	}
}

// net_fingerprint hashes the module's wire contract. `scripts` are the ROOT package's —
// the only ones that can carry wire surface — and `sub_classes` the struct names declared
// in SCRIPT SUBPACKAGES, which contribute their name and nothing else (see
// module_fingerprint for why they contribute it at all).
net_fingerprint :: proc(
	scripts: []^Script,
	sub_classes: []string,
	scripts_dir, abi_schema: string,
) -> u64 {
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)

	sorted := make([dynamic]^Script, 0, len(scripts), context.temp_allocator)
	append(&sorted, ..scripts)
	slice.sort_by(sorted[:], proc(a, b: ^Script) -> bool {return a.struct_name < b.struct_name})

	// ONE class stream, root scripts and subpackage names merged and sorted by name: the
	// `class <Name>` line lands in the same place either way, so a class that moves
	// between the root and a subfolder without changing its wire surface hashes the same.
	// (A subpackage entry carries no Script — there is nothing under it to write.)
	Fp_Class :: struct {
		name:   string,
		script: ^Script, // nil for a subpackage class
	}
	classes := make([dynamic]Fp_Class, 0, len(scripts) + len(sub_classes), context.temp_allocator)
	for s in sorted {append(&classes, Fp_Class{name = s.struct_name, script = s})}
	for n in sub_classes {append(&classes, Fp_Class{name = n})}
	slice.sort_by(classes[:], proc(a, b: Fp_Class) -> bool {return a.name < b.name})

	inputs := make([dynamic]string, context.temp_allocator) // distinct tick input types
	for c in classes {
		fmt.sbprintf(&b, "class %s\n", c.name)
		if c.script == nil {continue}
		s := c.script

		ents := make([dynamic]Entity_Tag, 0, len(s.entities), context.temp_allocator)
		append(&ents, ..s.entities[:])
		slice.sort_by(ents[:], proc(a, b: Entity_Tag) -> bool {return a.type_id < b.type_id})
		for e in ents {
			fmt.sbprintf(&b, "entity %s=%d\n", e.target, e.type_id)
		}

		// Declaration order is the descriptor order is the mask order: keep it.
		for r in s.replicates {
			fmt.sbprintf(
				&b,
				"rep %s:%s owner=%v predict=%v wire=%s/%s\n",
				strings.join(r.path, ".", context.temp_allocator),
				r.type_text,
				r.owner,
				r.predict,
				r.wire,
				r.codec,
			)
		}

		cmds := make([dynamic]string, context.temp_allocator)
		for c in s.commands {
			cb: strings.Builder
			strings.builder_init(&cb, context.temp_allocator)
			fmt.sbprintf(&cb, "cmd %s(", c.name)
			for a, i in c.args {
				if i > 0 {strings.write_string(&cb, ",")}
				strings.write_string(&cb, a.wire)
			}
			schedule := (s.tick.proc_name != "" || len(s.block_ticks) > 0) ? "tick" : "immediate"
			fmt.sbprintf(
				&cb,
				") access=%s prediction=%v max_args=%d schedule=%s",
				c.policy_access,
				c.policy_predict,
				c.policy_max_args,
				schedule,
			)
			append(&cmds, strings.to_string(cb))
		}
		slice.sort(cmds[:]) // ids are name-hashed; declaration order is not wire
		for c in cmds {
			fmt.sbprintf(&b, "%s\n", c)
		}

		// Declared world-pass facts: their ids ride SIM_FACT and their tuples
		// cross the wire — a drifted fact set is a drifted protocol.
		fcts := make([dynamic]string, context.temp_allocator)
		for f in s.facts {
			fb: strings.Builder
			strings.builder_init(&fb, context.temp_allocator)
			fmt.sbprintf(&fb, "fact %s(", f.name)
			first_wire := true
			for entity_type, i in f.entity_types {
				if i == f.anchor_index {continue}
				if !first_wire {strings.write_string(&fb, ",")}
				fmt.sbprintf(&fb, "ref:%s", entity_type)
				first_wire = false
			}
			for wr in f.arg_wires {
				if !first_wire {strings.write_string(&fb, ",")}
				strings.write_string(&fb, wr)
				first_wire = false
			}
			fmt.sbprintf(&fb, ") anchor=%s", f.anchor)
			append(&fcts, strings.to_string(fb))
		}
		slice.sort(fcts[:]) // ids are name-hashed; declaration order is not wire
		for f in fcts {
			fmt.sbprintf(&b, "%s\n", f)
		}

		// Declared typed app-messages (@(gd_message)): the tag→payload binding.
		// The payload's field LAYOUT is folded package-wide below (like profile
		// rows), so a drifted payload struct refuses at the join door too.
		msgs := make([dynamic]string, context.temp_allocator)
		for m in s.messages {
			append(
				&msgs,
				fmt.tprintf("msg %s tag=%s payload=%s", m.name, m.tag_ident, m.payload_type),
			)
		}
		slice.sort(msgs[:]) // registration order is not wire
		for m in msgs {
			fmt.sbprintf(&b, "%s\n", m)
		}

		if s.tick.proc_name != "" {
			fmt.sbprintf(
				&b,
				"tick input=%s class=%d contested=%v",
				s.tick.input_type,
				s.tick.input_class,
				s.tick.contested,
			)
			if s.tick.fx_mine {
				strings.write_string(&b, " facts=")
				for wr, i in s.tick.payload_wires {
					if i > 0 {strings.write_string(&b, ",")}
					strings.write_string(&b, wr)
				}
			}
			strings.write_string(&b, "\n")
			if s.tick.input_type != "" && !slice.contains(inputs[:], s.tick.input_type) {
				append(&inputs, s.tick.input_type)
			}
		}

		rpcs := make([dynamic]string, context.temp_allocator)
		for r in s.rpcs {
			rb: strings.Builder
			strings.builder_init(&rb, context.temp_allocator)
			fmt.sbprintf(&rb, "rpc %s m=%d t=%d ch=%d(", r.method, r.mode, r.transfer, r.channel)
			for m in s.methods {
				if m.gd_name != r.method {continue}
				for a, i in m.args {
					if i > 0 {strings.write_string(&rb, ",")}
					strings.write_string(&rb, a.vi.enum_name)
				}
				break
			}
			strings.write_string(&rb, ")")
			append(&rpcs, strings.to_string(rb))
		}
		slice.sort(rpcs[:])
		for r in rpcs {
			fmt.sbprintf(&b, "%s\n", r)
		}
	}

	// The input blobs, field by field — the one wire surface a type NAME can't
	// stand in for (editing a field inside Gunner_Input changes every packet).
	slice.sort(inputs[:])
	index_pkg_dir(scripts_dir) // idempotent; the scripts package indexes like any other
	if pkg, ok := g_pkgs[scripts_dir]; ok {
		for name in inputs {
			if def, has := pkg[name]; has {
				fmt.sbprintf(&b, "input-decl %s constrained=%v\n", name, def.input_decl)
				for f in def.fields {
					rules := ""
					if def.input_decl {
						rules, _ = tag_gd_value(f.tag)
					}
					fmt.sbprintf(&b, "in %s.%s:%s rules=%s\n", name, f.name, f.type_text, rules)
				}
			}
		}
		// The profile row (gd:"profile=T"), same reasoning: the row IS the
		// wire bytes, so its field-by-field shape gates the join — same-size
		// layout drift used to scramble rows PAST the version door.
		profs := make([dynamic]string, context.temp_allocator)
		for s in sorted {
			if s.profile_type != "" && !slice.contains(profs[:], s.profile_type) {
				append(&profs, s.profile_type)
			}
		}
		slice.sort(profs[:])
		for name in profs {
			if def, has := pkg[name]; has {
				for f in def.fields {
					fmt.sbprintf(&b, "profile %s.%s:%s\n", name, f.name, f.type_text)
				}
			}
		}
		// Typed app-message payloads (@(gd_message)), same reasoning: the payload
		// struct IS the wire bytes (session_app_send_typed raw-copies it), so its
		// field-by-field shape gates the join — a same-size drift would scramble a
		// message PAST the version door exactly like a profile row.
		mpays := make([dynamic]string, context.temp_allocator)
		for s in sorted {
			for m in s.messages {
				if !slice.contains(mpays[:], m.payload_type) {
					append(&mpays, m.payload_type)
				}
			}
		}
		slice.sort(mpays[:])
		for name in mpays {
			if def, has := pkg[name]; has {
				for f in def.fields {
					fmt.sbprintf(&b, "msg-payload %s.%s:%s\n", name, f.name, f.type_text)
				}
			}
		}
	}
	text := strings.to_string(b)
	check_fingerprint_contrib(scripts, scripts_dir, text)
	return fnv1a64(
		strings.concatenate({text, "canonical-abi\n", abi_schema}, context.temp_allocator),
	)
}

@(private = "file")
Guard_Entry :: struct {
	name: string,
	crc:  u32,
}

schema_lane_expr :: proc(lane: string) -> string {
	switch lane {
	case "owner": return ".Owner"
	case "predict": return ".Predict"
	}
	return ".Delta"
}

schema_access_expr :: proc(access: string) -> string {
	switch access {
	case "any-seat": return ".Any_Seat"
	case "authority": return ".Authority"
	}
	return ".Owner"
}

// Emit the public, package-level structured projection of the recursive ABI.
// The Wire_ABI_Metadata rows were collected while the canonical text was
// written; this function only renders those rows as Odin literals. It never
// re-parses declarations or the canonical string, which keeps one source of
// truth for introspection and fingerprinting.
gen_net_schema :: proc(b: ^strings.Builder, meta: ^Wire_ABI_Metadata) {
	w :: strings.write_string
	w(b, "// Structured projection of NET_SCHEMA_CANONICAL. Tables are flat/static;\n")
	w(b, "// spans link related rows without allocation or a second runtime registry.\n")

	w(b, "@(private = \"file\")\n_net_schema_entities := [?]_guard_knet.Net_Entity_Schema {\n")
	for e in meta.entities {
		fmt.sbprintf(
			b,
			"\t{{name = %q, wire_id = %d, stream_hz = %d, avatar = %v}},\n",
			e.name,
			e.wire_id,
			e.stream_hz,
			e.avatar,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_types := [?]_guard_knet.Net_Type_Schema {\n")
	for t in meta.types {
		fmt.sbprintf(
			b,
			"\t{{path = %q, kind = %q, width = %d, align = %d, detail = %q}},\n",
			t.path,
			t.kind,
			t.width,
			t.align,
			t.detail,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_fields := [?]_guard_knet.Net_Field_Schema {\n")
	for f in meta.fields {
		fmt.sbprintf(
			b,
			"\t{{path = %q, entity = %q, name = %q, lane = %s, encoding = %q, struct_width = %d, wire_width = %d, bound = %d, types = {{first = %d, count = %d}}}},\n",
			f.path,
			f.entity,
			f.name,
			schema_lane_expr(f.lane),
			f.encoding,
			f.struct_width,
			f.wire_width,
			f.bound,
			f.types.first,
			f.types.count,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_constraints := [?]_guard_knet.Net_Input_Constraint_Schema {\n")
	for c in meta.constraints {
		fmt.sbprintf(
			b,
			"\t{{field = %q, range = %q, mask = %q, finite = %v, unit = %v, enum_check = %v}},\n",
			c.field,
			c.range,
			c.mask,
			c.finite,
			c.unit,
			c.enum_check,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_inputs := [?]_guard_knet.Net_Input_Schema {\n")
	for input in meta.inputs {
		fmt.sbprintf(
			b,
			"\t{{path = %q, type_name = %q, class_id = %d, encoding = %q, width = %d, bound = %d, types = {{first = %d, count = %d}}, constraints = {{first = %d, count = %d}}}},\n",
			input.path,
			input.type_name,
			input.class_id,
			input.encoding,
			input.width,
			input.bound,
			input.types.first,
			input.types.count,
			input.constraints.first,
			input.constraints.count,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_arguments := [?]_guard_knet.Net_Argument_Schema {\n")
	for a in meta.arguments {
		fmt.sbprintf(
			b,
			"\t{{owner = %q, name = %q, kind = %q, target = %q, width = %d, bound = %d, variable = %v}},\n",
			a.owner,
			a.name,
			a.kind,
			a.target,
			a.width,
			a.bound,
			a.variable,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_action_outcomes := [?]_guard_knet.Net_Action_Outcome_Schema {\n")
	for outcome in meta.outcomes {
		fmt.sbprintf(
			b,
			"\t{{owner = %q, name = %q, type_name = %q}},\n",
			outcome.owner,
			outcome.name,
			outcome.type_name,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_actions := [?]_guard_knet.Net_Action_Schema {\n")
	for a in meta.actions {
		fmt.sbprintf(
			b,
			"\t{{path = %q, entity = %q, name = %q, id = %d, policy = {{access = %s, prediction = %s, max_args_bytes = %d}}, model = %s, args = {{first = %d, count = %d}}, outcomes = {{first = %d, count = %d}}",
			a.path,
			a.entity,
			a.name,
			a.id,
			schema_access_expr(a.access),
			a.prediction == "optimistic" ? ".Optimistic" : ".None",
			a.max_args,
			a.schedule == "tick" ? ".Scheduled" : ".Immediate",
			a.args.first,
			a.args.count,
			a.outcomes.first,
			a.outcomes.count,
		)
		if a.consequence != "" {
			fmt.sbprintf(
				b,
				", consequence = {{name = %q, authority_only = true, takes_game = %v}}",
				a.consequence,
				a.takes_game,
			)
		}
		w(b, "},\n")
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_facts := [?]_guard_knet.Net_Fact_Schema {\n")
	for f in meta.facts {
		fmt.sbprintf(
			b,
			"\t{{path = %q, entity = %q, name = %q, id = %d, anchor = %q, schedule = .Watch, source = %s, args = {{first = %d, count = %d}}}},\n",
			f.path,
			f.entity,
			f.name,
			f.id,
			f.anchor,
			f.source == "tick" ? ".Tick" : ".Declared",
			f.args.first,
			f.args.count,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_profiles := [?]_guard_knet.Net_Profile_Schema {\n")
	for p in meta.profiles {
		fmt.sbprintf(
			b,
			"\t{{path = %q, type_name = %q, encoding = %q, width = %d, bound = %d, types = {{first = %d, count = %d}}}},\n",
			p.path,
			p.type_name,
			p.encoding,
			p.width,
			p.bound,
			p.types.first,
			p.types.count,
		)
	}
	w(b, "}\n\n")

	w(b, "@(private = \"file\")\n_net_schema_messages := [?]_guard_knet.Net_Message_Schema {\n")
	for m in meta.messages {
		fmt.sbprintf(
			b,
			"\t{{path = %q, entity = %q, name = %q, payload_type = %q, tag = %d, tag_name = %q, encoding = %q, width = %d, bound = %d, types = {{first = %d, count = %d}}}},\n",
			m.path,
			m.entity,
			m.name,
			m.payload_type,
			m.tag,
			m.tag_name,
			m.encoding,
			m.width,
			m.bound,
			m.types.first,
			m.types.count,
		)
	}
	w(b, "}\n\n")

	w(b, "NET_SCHEMA := _guard_knet.Net_Schema {\n")
	fmt.sbprintf(b, "\tabi_version = %d,\n", WIRE_ABI_VERSION)
	w(b, "\tendian = .Little,\n")
	w(b, "\tabi_fingerprint = NET_ABI_FINGERPRINT,\n")
	w(b, "\tfingerprint = NET_FINGERPRINT,\n")
	w(b, "\tcanonical = NET_SCHEMA_CANONICAL,\n")
	w(b, "\tentities = _net_schema_entities[:],\n")
	w(b, "\ttypes = _net_schema_types[:],\n")
	w(b, "\tfields = _net_schema_fields[:],\n")
	w(b, "\tinputs = _net_schema_inputs[:],\n")
	w(b, "\tconstraints = _net_schema_constraints[:],\n")
	w(b, "\tactions = _net_schema_actions[:],\n")
	w(b, "\taction_outcomes = _net_schema_action_outcomes[:],\n")
	w(b, "\tfacts = _net_schema_facts[:],\n")
	w(b, "\targuments = _net_schema_arguments[:],\n")
	w(b, "\tprofiles = _net_schema_profiles[:],\n")
	w(b, "\tmessages = _net_schema_messages[:],\n")
	w(b, "}\n\n")
}

// The generated STALENESS GUARD: `#load_hash` re-hashes each authored source
// at COMPILE time and compares against the hash scriptgen saw when it
// generated — so building this package with stale *.gen.odin (any path that
// skips scriptgen, e.g. a bare `odin build`) fails loudly, naming the file
// that drifted, instead of compiling yesterday's descriptors and thunks over
// today's structs. A deleted or renamed source fails the #load_hash itself.
// Not covered, deliberately: files ADDED after generation (nothing references
// them yet), and imported block packages (godot:play/…) — the guard is this
// MODULE's contract with its own sources.
//
// `files` is the WHOLE module tree, each entry already named by its root-relative
// path — `#load_hash` resolves relative to the file that writes it, and the guard is
// written in the root, so `#load_hash("ui/hud.odin", …)` reaches the subpackage source.
//
// The guard is also where the module's IMPORT MANIFEST lives (`sub_imports`, root-relative
// dirs of the annotated subpackages). A subpackage's generated `@(init) rt.register(...)`
// only runs if the package is LINKED, and a subfolder of leaf classes has by definition
// nothing the root would otherwise name — so without the manifest those classes would
// compile, register nothing, and attach as placeholders. Blank side-effect imports keep
// the manifest from touching the root's namespace; `@(init)` procs of an imported package
// run regardless of whether anything references the package.
gen_guard :: proc(
	pkg: string,
	files: []Helper,
	fingerprint: u64,
	abi_fingerprint: u64,
	abi_schema: string,
	abi_metadata: ^Wire_ABI_Metadata,
	kit_wire: bool,
	sub_imports: []string,
) -> string {
	entries := make([dynamic]Guard_Entry, 0, len(files), context.temp_allocator)
	for f in files {
		append(
			&entries,
			Guard_Entry{name = norm_path(f.path), crc = hash.crc32(transmute([]u8)f.src)},
		)
	}
	// Deterministic output whatever order the directory listed in.
	slice.sort_by(entries[:], proc(a, b: Guard_Entry) -> bool {return a.name < b.name})

	b: strings.Builder
	strings.builder_init(&b)
	w :: strings.write_string
	fmt.sbprintf(&b, "package %s\n\n", pkg)
	if kit_wire {
		w(&b, "import _guard_knet \"godot:kit/net\"\n")
		w(&b, "import _guard_ksess \"godot:kit/session\"\n\n")
	}
	if len(sub_imports) > 0 {
		w(&b, "// THE IMPORT MANIFEST: one blank side-effect import per SCRIPT SUBPACKAGE, so\n")
		w(&b, "// each subfolder's generated `@(init)` class registration is linked into this\n")
		w(&b, "// module's one dll. Nothing else in the module names these packages.\n")
		sorted := slice.clone_to_dynamic(sub_imports, context.temp_allocator)
		slice.sort(sorted[:])
		for rel in sorted {
			fmt.sbprintf(&b, "import _ %q\n", rel)
		}
		w(&b, "\n")
	}
	w(&b, "// GENERATED by scriptgen — do not edit. THE STALENESS GUARD: each assert\n")
	w(&b, "// re-hashes an authored source at compile time; a mismatch means this\n")
	w(&b, "// package's *.gen.odin predates the source it claims to mirror — the build\n")
	w(&b, "// path skipped scriptgen. Build via build_scripts.sh (it re-runs scriptgen),\n")
	w(&b, "// or re-run scriptgen over this directory by hand.\n\n")
	w(&b, "// The package's WIRE CONTRACT, hashed — recursive canonical field layouts,\n")
	w(&b, "// bounds, action policies/schedules, entity ids, fact tuples, and rpcs. It is\n")
	w(&b, "// registered as the session's default fingerprint, so a skewed build is refused\n")
	w(&b, "// AT THE DOOR (Deny_Reason.Version) instead of misparsing every delta into\n")
	w(&b, "// garbage fields — no wiring needed. Session_Config.fingerprint overrides\n")
	w(&b, "// (ksess.FINGERPRINT_NONE disables the gate on purpose).\n")
	fmt.sbprintf(&b, "NET_ABI_FINGERPRINT :: u64(0x%016x)\n", abi_fingerprint)
	fmt.sbprintf(&b, "NET_SCHEMA_CANONICAL :: `%s`\n", abi_schema)
	fmt.sbprintf(&b, "NET_FINGERPRINT :: u64(0x%016x)\n\n", fingerprint)
	if kit_wire {
		gen_net_schema(&b, abi_metadata)
		w(&b, "@(init)\n_register_net_fingerprint :: proc \"contextless\" () {\n")
		w(&b, "\t_guard_ksess.default_net_fingerprint = NET_FINGERPRINT\n")
		w(&b, "}\n\n")
	}
	for e in entries {
		fmt.sbprintf(
			&b,
			"#assert(\n\t#load_hash(%q, \"crc32\") == 0x%08x,\n\t\"%s changed after scriptgen ran — *.gen.odin is STALE; build via build_scripts.sh (it re-runs scriptgen), or re-run scriptgen over this dir\",\n)\n",
			e.name,
			e.crc,
			e.name,
		)
	}
	return strings.to_string(b)
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
	w(
		&b,
		"// `odin_scripts_boot` immediately after it dlopens this compiled scripts dll, so the\n",
	)
	w(&b, "// dll can initialize its OWN gdext/godot package globals before any of your script\n")
	w(
		&b,
		"// procs run. Define your own `odin_scripts_boot` in a hand-written file to opt out.\n\n",
	)
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
