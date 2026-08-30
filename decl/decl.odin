package gd_decl

// decl — THE DECLARATION SCHEMA: the vocabulary of the `gd:"…"` tag language
// and its `@(gd_*)` attributes, written down ONCE, in the one place both
// halves of the toolchain can import.
//
// WHY THIS PACKAGE EXISTS. The language's vocabulary used to live as
// open-coded per-context if-chains in four or five files that had to agree by
// discipline, and every one of them was a real sync surface with a real bug
// history:
//
//   * scriptgen/parse.odin's tag dispatch — the reader.
//   * runtime/register_class.odin's walk_field skip list — the reflector.
//     `backup` spent a while missing from it and every backup field logged a
//     bogus "unknown gd tag" on every boot.
//   * the "expected `export`, `onready=PATH`, …" error text beside that skip,
//     which had to be re-edited by hand to match it.
//   * the wrong-namespace sniff in parse.odin (`gs:"replicate"` would silently
//     not replicate), which carried its own third copy of the token list.
//   * build/common.sh's ODIN_GD_ATTRS and build_scripts.ps1's twin — the
//     attribute allowlist, without which a `@(gd_*)` proc is a COMPILE ERROR.
//
// The repo's own table-driven parts (SESSION_EVENTS, MIGRATION_HALVES) are
// where the fewest bugs have lived: each drives pairing, shape, roles,
// dispatch and hints from ONE row. This is that shape applied to the
// vocabulary itself — the table is the source, everything else is a
// PROJECTION of it.
//
// DELIBERATELY NOT HERE: the shape grammars (a tick's signature, a half's
// parameter order, the by/mine/pointer-after-receiver conventions). Those stay
// as code in scriptgen. A table of shapes would recreate the same problem as a
// worse DSL — the point of a schema is that it is small enough to read.

import "core:strings"

// ---- field tokens: the `gd:"…"` vocabulary ---------------------------------

// How a token is recognized. A Prefix token carries a value after its `=`.
Match :: enum u8 {
	Exact,
	Prefix
}

// Where a token may appear inside the tag. FIRST tokens select the field's
// KIND; SPEC tokens ride behind one, tuning it.
//
// THE RULE, now that the language enforces it evenly: A WIRE DECLARATION IS A
// FIRST TOKEN. If the thing folds into NET_FINGERPRINT — a lane, a profile row,
// an entity's stable type id — it names the field's kind and leads the tag.
// `entity=` used to ride as a spec of `export` while `profile=` led, with no
// derivable reason, and this comment recorded that as known-and-unfixed; the
// `entity=Name:id` first form retired it. What remains behind a first token is
// genuinely subordinate: an export's Inspector dressing, a signal's parameter
// names, a lane's tuning knobs. The `fingerprint` column below is the tell —
// every true row is a First.
Slot :: enum u8 {
	First,
	Spec
}

// WHO consumes the token — the fact the runtime's skip list is a projection
// of. A Scriptgen token is fully handled at build time (it became a descriptor
// table, a backup codec, a profile install); the runtime must therefore SKIP
// it rather than report it as unknown. `entity=` is the one token BOTH halves
// act on — scriptgen builds the factory table from it, and the runtime still
// owes the Inspector the PackedScene slot the author no longer spells out — so
// it is Reflect, and walk_field synthesizes the export it implies.
//
// This column also decides WHO type-checks a field, and at what depth. The
// runtime's reflection walk type-checks every Reflect token (export's Variant
// mapping, onready's object-handle requirement) at ANY depth and drops a bad one
// with a loud record_error at registration — so scriptgen validates the TYPE of
// a Reflect token at top level only and defers nested ones to the runtime that
// owns them. (Widening scriptgen's textual, gd.-only map_variant to nested
// fields would false-positive on the foreign-package bundle types nested fields
// usually carry, which the runtime's typeid check resolves and scriptgen's
// cannot.) A Scriptgen token has no such fallback, so scriptgen type-checks it
// at EVERY depth. See the seam note in scriptgen/parse.odin's Tagged_Field.
Home :: enum u8 {
	Reflect, // the runtime's reflection registrar acts on it (and type-checks it, at any depth)
	Scriptgen, // consumed entirely at build time; nothing to reflect — scriptgen type-checks it
}

Field_Token :: struct {
	name:        string,
	match:       Match,
	slot:        Slot,
	home:        Home,
	// Its shape folds into NET_FINGERPRINT, so a build that disagrees about it
	// is refused at the JOIN door rather than misparsing packets. This column
	// is what makes "a declaration that crosses the wire but not the version
	// door" a thing you can SEE instead of a thing you discover in the field.
	//
	// It is checked, not merely written down: scriptgen's FINGERPRINT_CONTRIB
	// carries one row per token naming the line net_fingerprint writes for it,
	// and refuses the build if a row and this column disagree, or if a token
	// this column claims is declared by the corpus and left no trace in the
	// hashed string. That check found the column's first lie on the day it was
	// added — `backup` shipped as true and was never serialized. FALSE is right:
	// a backup is guarded by the codec's own fnv1a32 format stamp at the LOAD
	// door, and refusing a JOIN over save-file shape would ground two peers
	// whose saves were never going to meet. The general rule the row follows:
	// true iff the declaration's shape must match across a SOCKET, not merely
	// across a file.
	fingerprint: bool,
	// How the token is spelled in an error message ("`onready=PATH`"), and the
	// one-line gloss the docs table shows.
	spelling:    string,
	blurb:       string
}

// THE THREE LANES ARE THREE TOKENS. `owner` and `predict` used to be options
// inside `gd:"replicate,…"`, which made the LANE — the one thing that decides
// who writes the field's bytes — syntactically indistinguishable from a
// tuning knob, and cost the parser a ~220-line pairwise constraint matrix
// (owner-xor-predict, slack-needs-predict, glide/cut-needs-predict-and-interp)
// whose every rule existed only because the lane came last. Leading with the
// lane makes each lane's option set CLOSED and checkable on its own, and makes
// the illegal combinations unspellable instead of merely rejected.
FIELD_TOKENS :: []Field_Token {
	{"export", .Exact, .First, .Reflect, false, "`export`", "an editor-visible property"},
	{"onready=", .Prefix, .First, .Reflect, false, "`onready=PATH`", "an auto-wired node reference"},
	{"replicate", .Exact, .First, .Scriptgen, true, "`replicate`", "a networked field on the DELTA lane (kit/net descriptors)"},
	{"owner", .Exact, .First, .Scriptgen, true, "`owner`", "a networked field streamed from its owning peer"},
	{"predict", .Exact, .First, .Scriptgen, true, "`predict`", "a networked field the sim predicts and reconciles (kit/sim)"},
	{"backup", .Exact, .First, .Scriptgen, false, "`backup`", "a field the session backup carries"},
	{"manual", .Exact, .First, .Scriptgen, false, "`manual`", "I call the generated thing myself"},
	{"profile=", .Prefix, .First, .Scriptgen, true, "`profile=T`", "the per-player profile row type"},
	{"entity=", .Prefix, .First, .Reflect, true, "`entity=Name:id`", "a spawnable entity type and its stable id (an exported PackedScene slot, synthesized)"},
	{"args=", .Prefix, .Spec, .Reflect, false, "`args=a,b`", "a signal payload's parameter names"}
}

// The three replication lanes, in the order the docs table reads. Each is a
// FIRST token; `replicate_lane` answers "is this token a lane, and which".
Lane :: enum u8 {
	None,
	Delta, // `replicate` — host-authoritative, byte-diffed, `_edge` halves pair here
	Owner, // `owner`     — streamed from the owning peer, interpolated
	Predict, // `predict`   — sim-predicted, reconciled against server truth
}

replicate_lane :: proc(tok: string) -> Lane {
	switch tok {
	case "replicate":
		return .Delta
	case "owner":
		return .Owner
	case "predict":
		return .Predict
	}
	return .None
}

// The token `tok` selects, if the vocabulary knows it. `tok` is one
// comma-separated piece of a tag, already trimmed.
field_token :: proc(tok: string) -> (Field_Token, bool) {
	for t in FIELD_TOKENS {
		switch t.match {
		case .Exact:
			if tok == t.name {
				return t, true
			}
		case .Prefix:
			if strings.has_prefix(tok, t.name) {
				return t, true
			}
		}
	}
	return {}, false
}

// PROJECTION — the runtime's skip list: true when the token was consumed
// whole at build time, so reflection must pass over it in silence.
field_is_build_only :: proc(tok: string) -> bool {
	t, ok := field_token(tok)
	return ok && t.home == .Scriptgen
}

// PROJECTION — the "expected …" half of an unknown-tag error, in declaration
// order, first tokens only (a spec's error names its own carrier).
field_expected :: proc(allocator := context.allocator) -> string {
	firsts: [dynamic]string
	defer delete(firsts)
	for t in FIELD_TOKENS {
		if t.slot == .First {
			append(&firsts, t.spelling)
		}
	}
	b := strings.builder_make(allocator)
	for sp, i in firsts {
		if i > 0 {
			strings.write_string(&b, i == len(firsts) - 1 ? ", or " : ", ")
		}
		strings.write_string(&b, sp)
	}
	return strings.to_string(b)
}

// PROJECTION — the wrong-namespace sniff: is this payload UNMISTAKABLY ours?
// `gs:"replicate"` contains no "gd:" at all and would silently not replicate,
// so a tag whose first token is one of ours is flagged whatever namespace it
// wears.
field_token_shaped :: proc(tok: string) -> bool {
	_, ok := field_token(tok)
	return ok
}

// ---- the per-context policy: WHERE a tag may appear, and what it means there ---
//
// A `gd:"..."` tag rides one of two field SITES: the script struct's own field,
// or a field reached through a `using`/embedded block. A handful of tokens mean
// different things — or nothing legal — at depth, and for most of scriptgen's
// life that per-site difference was expressed as two separate hand-written
// dispatch chains that drifted: a nested typo was a silent no-op where the same
// typo at top level was a hard error, and a nested `manual` swallowed a whole
// sub-block with no diagnostic. The two chains are now one walk, and THIS is the
// table it consults for the context question — may this token appear here — the
// answer decided in data rather than re-derived in two places.
//
// A THIRD site, "block-proc", appears in this schema's earliest sketch. It is
// deliberately absent, and its absence is the decision this column closes: it is
// not a field site at all but the @(gd_command)/@(gd_method)/@(gd_tick) HOISTING
// that a composed block performs, whose verb ("hoist") has no field-tag meaning.
// Fields and procs are two dispatches; this is the field one. Named here so the
// sketch's missing column reads as a ruling, not an oversight.
Field_Site :: enum u8 {
	Top_Level, // a field of the script struct itself
	Nested, // a field reached through a `using`/embedded block
}

// What the shared dispatch does with a KNOWN token at a site, BEFORE any
// kind-specific work runs. (An UNKNOWN token never reaches the table — it is
// refused by the field_token_shaped gate.) This owns exactly the context
// question the two walks used to answer inconsistently, and nothing about what a
// token MEANS once it is allowed, which stays scriptgen's to know.
Field_Action :: enum u8 {
	Handle, // the dispatch's arm acts on it (whether it RECORDS may still narrow by site)
	Caller, // consumed by the CALLER before the shared dispatch — reaching it is a toolchain bug
	Refuse, // illegal at this site; `reason` says why, in the author's own terms
}

Field_Policy :: struct {
	token:  string, // a FIELD_TOKENS name, verbatim
	site:   Field_Site,
	action: Field_Action,
	// For Refuse: the whole sentence after "<Class>.<path>: ", its own backticked
	// token spelling included. It lives here as DATA, not as a literal in the
	// dispatch, so the same refusal can never again be worded two ways in two
	// places — which is exactly how the two sites drifted apart. "" for Handle /
	// Caller (the completeness check enforces the pairing both directions).
	reason: string
}

// THE TABLE. One row per (FIELD_TOKENS token x Field_Site); scriptgen's
// check_field_policy refuses to generate if a token is missing a row at either
// site, or a Refuse row has no reason, or a non-Refuse row carries one — the
// mechanism that keeps this honest, the way FINGERPRINT_CONTRIB keeps the
// fingerprint column honest. A new token added above without two rows here fails
// the build, naming itself.
FIELD_POLICY :: []Field_Policy {
	// The three lanes and backup: a networked or host-local field means the same
	// thing at any depth (the kit bundles carry replicate fields several levels
	// down; scrapyard tags backup fields inside a `using` embed).
	{"replicate", .Top_Level, .Handle, ""},
	{"replicate", .Nested, .Handle, ""},
	{"owner", .Top_Level, .Handle, ""},
	{"owner", .Nested, .Handle, ""},
	{"predict", .Top_Level, .Handle, ""},
	{"predict", .Nested, .Handle, ""},
	{"backup", .Top_Level, .Handle, ""},
	{"backup", .Nested, .Handle, ""},
	// Editor dressing, registered by the runtime reflection walk at every depth:
	// scriptgen validates the tag in both places (the spelling + arity gates) and
	// RECORDS only at top level — an embed's exports register under their
	// namespaced names, not scriptgen's own table. "Handle" both; the record-skip
	// is the arm's, since it is a what-it-means detail, not a may-it-appear one.
	{"export", .Top_Level, .Handle, ""},
	{"export", .Nested, .Handle, ""},
	{"onready=", .Top_Level, .Handle, ""},
	{"onready=", .Nested, .Handle, ""},
	// The three that name the CLASS's OWN field and silently wire nothing nested —
	// each was a real "declared but never installed" failure reached through a
	// block, and each refusal names the specific thing that goes missing.
	{"profile=", .Top_Level, .Handle, ""},
	{
		"profile=",
		.Nested,
		.Refuse,
		"`profile=` declares on the class's OWN ksess.Session field — nested in an embed it silently never installs; move the declaration to the top level"
	},
	{"entity=", .Top_Level, .Handle, ""},
	{
		"entity=",
		.Nested,
		.Refuse,
		"`entity=` declares on the class's OWN scene field — nested in an embed the export registers but the factory/type row silently never exists; move the field to the top level"
	},
	// `manual` opts an embed's tick out of auto-hoist. TOP LEVEL the caller
	// (parse_script) consumes it — it recurses the embed and suppresses only the
	// auto-call — so it must NEVER reach the shared dispatch; Caller is that
	// contract, and the dispatch asserts on it. NESTED it has never meant
	// anything and used to eat the subtree.
	{"manual", .Top_Level, .Caller, ""},
	{
		"manual",
		.Nested,
		.Refuse,
		"`gd:\"manual\"` only works on the class's OWN embed — nested one level down it silently skips the whole sub-block (no predict fields, no backups, no tick). Move the embed to the top level and tag it there"
	},
	// A signal payload's parameter NAMES: a Spec token (it rides behind a signal
	// TYPE), so as a leading token it is the wrong slot at either site.
	{"args=", .Top_Level, .Refuse, "`args=` is only valid on a signal field (gd.Signal0 … gd.Signal4)"},
	{"args=", .Nested, .Refuse, "`args=` is only valid on a signal field (gd.Signal0 … gd.Signal4)"}
}

// The policy for `token` (a FIELD_TOKENS name) at `site`. ok=false means the
// table has no row — a hole the completeness check turns into a build error, so
// a caller may treat !ok as "the schema is incomplete", never as "allowed".
field_policy :: proc(token: string, site: Field_Site) -> (Field_Policy, bool) {
	for p in FIELD_POLICY {
		if p.token == token && p.site == site {
			return p, true
		}
	}
	return {}, false
}

// ---- export specs: the tokens that ride BEHIND `export` --------------------

// WHY THIS TABLE EXISTS. The `gd:"export,…"` spec set had exactly ONE reader
// (runtime/register_class.odin: walk_field's group/subgroup/default/get/set/
// entity switch, and parse_hint_spec's range/enum/multiline/file/dir/
// global_file/global_dir/resource/array/dict switch), and scriptgen's own
// export-spec loop had NO default arm — an unrecognized spec just fell
// through. That made the two validation tiers illegible: `gd:"replicate,
// slcak=0.5"` failed the BUILD, while `gd:"export,rnage=0:100"` sailed past
// scriptgen and only died at BOOT, as a record_error in the editor's output,
// on a field that silently lost its hint. Same typo, same tag, two different
// error latencies and two different audiences.
//
// This table is what lets scriptgen refuse a misspelled spec at BUILD time
// without owning a sixth copy of the list, and — since walk_field started
// SELECTING on it rather than being asserted against it — it is also what
// decides which of the runtime's two switches a name reaches. It was briefly
// only a document: tests/scriptgen extracted both switches' case labels with
// awk and asserted them equal to this table, which could see drift but not stop
// it, and left the runtime's own dispatch with no default arm at all. The
// runtime is still the CONSUMER — it owns what each spec MEANS (a value's type,
// a hint's arity, the Variant it requires) — and each row here owns only that
// the name EXISTS and which KIND of thing it is, which is exactly what a
// spelling check and a two-way dispatch need and no more.
Export_Spec_Kind :: enum u8 {
	Meta, // Inspector/codegen plumbing — never a Property_Hint
	Hint, // becomes the field's ONE Property_Hint (at most one per field)
}

Export_Spec :: struct {
	name:  string,
	kind:  Export_Spec_Kind,
	// Does the spec carry a `=VALUE`? Tri-state as two bools so `file` (legal
	// bare AND with a filter list) is representable — a spelling check that
	// insisted on one or the other would refuse working tags.
	bare:  bool, // legal as a bare token
	value: bool, // legal as `name=VALUE`
	blurb: string
}

EXPORT_SPECS :: []Export_Spec {
	{"group", .Meta, false, true, "open an Inspector group header here"},
	{"subgroup", .Meta, false, true, "open an Inspector subgroup header here"},
	{"default", .Meta, false, true, "a scalar export's initial value"},
	{"get", .Meta, false, true, "route reads through a proc"},
	{"set", .Meta, false, true, "route writes through a proc"},
	{"range", .Hint, false, true, "`range=MIN:MAX[:STEP]` — a slider"},
	{"enum", .Hint, false, true, "`enum=A:B:C` — a dropdown"},
	{"multiline", .Hint, true, false, "a multi-line text box"},
	{"file", .Hint, true, true, "a file picker (`file=*.png` filters)"},
	{"dir", .Hint, true, true, "a directory picker"},
	{"global_file", .Hint, true, true, "a filesystem-wide file picker"},
	{"global_dir", .Hint, true, true, "a filesystem-wide directory picker"},
	{"resource", .Hint, false, true, "`resource=Class` — a typed Resource slot"},
	{"array", .Hint, false, true, "`array=ELEM` — a typed gd.Array"},
	{"dict", .Hint, false, true, "`dict=KEY;VALUE` — a typed gd.Dictionary"}
}

export_spec :: proc(name: string) -> (Export_Spec, bool) {
	for s in EXPORT_SPECS {
		if s.name == name {
			return s, true
		}
	}
	return {}, false
}

// THE ENTITY'S OWN TRAILING TOKENS — knobs of the KIND `entity=Name:id`
// declares, riding behind it beside any export specs (`entity=Mob:3,
// stream_hz=30,group=Spawns`). scriptgen CONSUMES them (onto the generated
// kboot.Entity_Kind row); the runtime, which synthesizes the export the
// declaration implies and walks its trailing specs, must SKIP them rather
// than report an unknown export spec — this table is what both halves read,
// so a new knob is one row, not a scriptgen string and a runtime string that
// drift. (The registration error the first draft logged — "unknown export
// spec `avatar`" — is the failure mode this row prevents.)
Entity_Spec :: struct {
	name:  string,
	bare:  bool, // legal as a bare token
	value: bool, // legal as `name=VALUE`
	blurb: string
}

ENTITY_SPECS :: []Entity_Spec {
	{"stream_hz", false, true, "`stream_hz=N` — the kind's owner-stream rate, applied to every spawn of the type on every peer"},
	{"avatar", true, false, "`avatar` — this kind is a seat's body: a host takeover parks it with its seat instead of adopting it"}
}

entity_spec :: proc(name: string) -> (Entity_Spec, bool) {
	for s in ENTITY_SPECS {
		if s.name == name {
			return s, true
		}
	}
	return {}, false
}

// PROJECTION — the whole spec set, comma-joined, for the fallback half of a
// misspelling error. Declaration order (meta first, then hints) is the order
// the docs table reads in, so the message and the page agree. The "did you
// mean" half is the CALLER's: scriptgen already owns an edit_distance_le1 for
// its lifecycle-typo warnings, and a second copy here would be exactly the
// kind of hand-kept twin this package exists to delete.
export_specs_list :: proc(allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	for s, i in EXPORT_SPECS {
		if i > 0 {
			strings.write_string(&b, ", ")
		}
		strings.write_string(&b, s.name)
	}
	return strings.to_string(b)
}

// ---- proc attributes -------------------------------------------------------

// An attribute's family, which is what the exclusivity rules are written in
// terms of: a proc may carry at most ONE kit primary, and a kit primary never
// shares a proc with a method-family attribute (the kit verbs never join the
// engine's method tables).
//
// THE LINE BETWEEN Kit_Primary AND Half, since `gd_fact` sat on the wrong side
// of it until the halves became declarative: a PRIMARY makes a declaration —
// something downstream is generated FROM it (a verb's wrapper, a tick's thunk,
// a fact's announce door and its wire id). A HALF pairs with a declaration made
// elsewhere and generates nothing; the name says which declaration, the
// attribute says only that pairing is INTENDED. `gd_fact` generates a door and
// claims a wire id, so it is a primary that happens to bind its bearer by name;
// `gd_half` is the one member of Half, and pairing with nothing is its error.
Attr_Family :: enum u8 {
	Kit_Primary, // the toolkit verbs: the proc IS a command / tick / sample / step / fact door
	Kit_Declaration, // a toolkit type declaration (currently @(gd_input) on an input struct)
	Method, // engine-facing: it joins a method, rpc, or signal table
	Half, // it pairs with a declaration made elsewhere
}

Attr :: struct {
	name:   string, // WITHOUT the `gd_` prefix stripped — the spelling Odin sees
	family: Attr_Family,
	blurb:  string
}

// THE ALLOWLIST. Odin refuses an unknown custom attribute outright, so every
// name here must reach the compiler as `-custom-attribute:<name>` on EVERY
// build of game scripts. tests/scriptgen asserts build/common.sh and
// build_scripts.ps1 carry exactly this set — a name added here without the
// build flags is a compile error in every game, and the test says so at home
// instead of in someone's project.
ATTRS :: []Attr {
	{"gd_method", .Method, "an engine-callable method"},
	{"gd_connect", .Method, "a signal handler, connected by name"},
	{"gd_rpc", .Method, "an engine RPC"},
	{"gd_command", .Kit_Primary, "a kit/net command verb"},
	{"gd_tick", .Kit_Primary, "a sim tick"},
	{"gd_input", .Kit_Declaration, "a constrained simulation input struct"},
	{"gd_sample", .Kit_Primary, "an input sample"},
	{"gd_step", .Kit_Primary, "a sim step"},
	{"gd_event", .Kit_Primary, "a reliable presentation event with declared audience and timing"},
	{"gd_cue", .Kit_Primary, "a presentation cue with an inferred or named entity anchor"},
	{"gd_fact", .Kit_Primary, "the compatible earlier spelling for a presentation cue"},
	{"gd_message", .Kit_Primary, "a typed app-message handler (kit/session app route)"},
	{"gd_half", .Half, "a pairing half; the NAME says what it pairs with"}
}

attr :: proc(name: string) -> (Attr, bool) {
	for a in ATTRS {
		if a.name == name {
			return a, true
		}
	}
	return {}, false
}

// ---- ids: the hash law -----------------------------------------------------
//
// FNV-1a, and nothing else, everywhere an id must be STABLE across builds.
// There were three hand-inlined copies of this arithmetic before this file
// (one 64-bit, two 32-bit), which is three chances to typo a constant into a
// hash that only disagrees on the packets nobody tested.
//
// THE NAMESPACES, and why each is what it is:
//
//   wire_id16   command verbs and world-pass facts. Folded to u16 because it
//               rides every packet. Reordering or adding declarations can no
//               longer renumber the protocol; a version-skewed peer's unknown
//               id MISSES the receiver's lookup and rejects cleanly instead of
//               dispatching to whatever now lives at that position. A RENAMED
//               verb is a new id on purpose: it IS a different verb. Commands
//               and facts share the arithmetic but NOT the space — each gets
//               its own collision check, because they are looked up in
//               different tables.
//   fnv1a32     the backup format stamp: a hash of the codec's field signature,
//               so a save written by a drifted build is refused rather than
//               misread.
//   fnv1a64     NET_FINGERPRINT: the whole wire contract in one number.
//
// Entity type ids are the deliberate exception — the AUTHOR assigns them
// (`entity=Name:id`), because they are a permanent public numbering that must
// survive a rename.

FNV64_OFFSET :: u64(0xcbf29ce484222325)
FNV64_PRIME :: u64(0x100000001b3)
FNV32_OFFSET :: u32(0x811c9dc5)
FNV32_PRIME :: u32(0x01000193)

fnv1a64_acc :: proc(h: u64, s: string) -> u64 {
	h := h
	for i in 0 ..< len(s) {
		h ~= u64(s[i])
		h *= FNV64_PRIME
	}
	return h
}

fnv1a64 :: proc(s: string) -> u64 {
	return fnv1a64_acc(FNV64_OFFSET, s)
}

fnv1a32_acc :: proc(h: u32, s: string) -> u32 {
	h := h
	for i in 0 ..< len(s) {
		h ~= u32(s[i])
		h *= FNV32_PRIME
	}
	return h
}

fnv1a32 :: proc(s: string) -> u32 {
	return fnv1a32_acc(FNV32_OFFSET, s)
}

// The wire id a verb or fact is known by: FNV-1a of its name, xor-folded to
// u16 (see the namespace note above).
wire_id16 :: proc(name: string) -> u16 {
	h := fnv1a32(name)
	return u16(h >> 16) ~ u16(h & 0xFFFF)
}
