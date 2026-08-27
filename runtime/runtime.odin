package script_runtime

import "godot:gdext"

// ----------------------------------------------------------------------------
// runtime — the shared contract between the CORE dll and the compiled SCRIPTS dll.
//
// This package is compiled INTO the scripts dll (where scripts self-register their
// Class_Desc from `@(init)`), and its TYPES are also imported by the core so the
// core can interpret the manifest the scripts dll hands back.
//
// It is deliberately PURE DATA: `register` only touches the scripts-dll-local
// registry and never calls into godot/gdext. That is what makes it safe to run
// from `@(init)` (on dlopen, BEFORE the core has had a chance to boot the scripts
// dll's gdext/godot globals). The engine-touching work (set_position, Input, ...)
// happens later, inside the lifecycle procs, which only run after boot.
// ----------------------------------------------------------------------------

// Per-class lifecycle entry points. A nil field means "this class does not handle
// that callback" — the core checks for nil before dispatching.
Lifecycle :: struct {
	ready:            proc "c" (self: rawptr),
	enter_tree:       proc "c" (self: rawptr),
	exit_tree:        proc "c" (self: rawptr),
	process:          proc "c" (self: rawptr, delta: f64),
	physics_process:  proc "c" (self: rawptr, delta: f64),
	// `reload` runs after a HOT RELOAD swaps the scripts dll, on each live instance (with
	// its NEW code). Lets a script rebuild state the swap can't fix itself — chiefly raw
	// proc pointers cached into its struct (callback/dispatch tables, behaviour-tree nodes
	// like flow.Action), which on a same-layout reload are preserved byte-for-byte and so
	// still point at the OLD (stale, but still-mapped) code. Authored as `<class>_reload`.
	reload:           proc "c" (self: rawptr),
}

// ----------------------------------------------------------------------------
// Phase 3 member descriptors. These are PURE DATA published from `@(init)`; they
// reference static (package-global) backing arrays in the scripts dll, which stay
// alive for the dll's lifetime. The CORE reads them across the dll boundary.
// ----------------------------------------------------------------------------

// An `@export` var: a field in the script struct surfaced to GDScript/Inspector.
//   - `type`   is the Godot Variant type the property presents as.
//   - `offset` is `offset_of(T, field)` — byte offset of the field in the struct.
//   - `size`   is `size_of(field_type)` — needed so the core narrows a Variant's
//     native width (Int=i64, Float=f64) down to the field's real width (e.g. f32).
//   - `hint`/`hint_string` drive the Inspector editor widget (range slider, enum
//     dropdown, multiline text, file/dir picker, typed resource picker). `hint` is a
//     `godot.Property_Hint` int value (0 == None); `hint_string` is its companion
//     string (e.g. "0,100,5" for a Range, "A,B,C" for an Enum). They are reported
//     verbatim in every PropertyInfo the core builds for this export.
Export :: struct {
	name:        cstring,
	type:        gdext.Variant_Type,
	offset:      uintptr,
	size:        int,
	hint:        i64,
	hint_string: cstring,
	// `@export` group/subgroup markers (richer-authoring #2). When non-nil, the Inspector
	// renders a collapsible GROUP (or SUBGROUP) header immediately BEFORE this property; it
	// applies to subsequent exports until the next marker. (`group`/`subgroup` hold the
	// header label; the group's property-name prefix is "" — we don't auto-prefix names.)
	group:       cstring,
	subgroup:    cstring,
	// `@export` default value (richer-authoring #3). `has_default` => apply on instance
	// create (after zeroing, before _ready) AND report via _get/_has_property_default_value.
	// Scalars only: Int/Float/Bool live in `default_num` (bool as 0/1), String in `default_str`.
	has_default: bool,
	default_num: f64,
	default_str: cstring,
	// Getter/setter routing (richer-authoring #4). When non-nil, the core's inst_get/inst_set
	// call these generated wrappers (which marshal Variant<->typed + call the author's proc)
	// instead of reading/writing the raw field. nil => plain offset-based field access.
	getter:      proc "c" (self: rawptr, ret: gdext.VariantPtr),
	setter:      proc "c" (self: rawptr, value: gdext.VariantPtr),
	// 1-based source line of the field in the authored `.odin`, for `_get_member_line`
	// (editor jump-to-member / member outline). 0 == unknown.
	line:        i32,
	// `///` doc comment above the field (property description in the editor doc panel). nil/"" == none.
	doc:         cstring,
}

// An `@onready`-style auto-wired node reference (richer-authoring #1). On the node's
// READY — BEFORE `@(gd_connect)` connections and the user's `_ready` — the core resolves
// `get_node(owner, path)` and writes the resulting Object pointer into the script field at
// `offset`. The field is a private auto-wired ref (NOT a serialized @export), so it never
// appears in the property/export list. Mirrors the Connection flow exactly.
//
// SCRIPT-RESOLVING form: a field typed `^<script struct>` (`hud: ^hud `gd:"onready=..."``)
// wants the target node's Odin SCRIPT STRUCT, not the node handle — the core resolves
// `get_node` and then the struct via its class-checked resolver (rt.script_of semantics),
// collapsing the two-field handle+`rt.script_of`-in-ready idiom into one declaration.
// `script_id` is the pointee's typeid, recorded by the reflection walk; like Class_Desc.id
// it is DLL-LOCAL and opaque to the core. The walk cannot resolve it to a class name
// (the target's own `@(init)` may not have run yet), so `script_class` is filled in by
// fixup_onready_script_targets once the manifest is first pulled — nil script_class +
// non-nil script_id never reaches the core (a failed fixup neutralizes the entry by
// nil'ing `path`, which the core skips). `field` is the field's name, for error messages.
//
// ARRAY form — `cards: [9]gd.Button `gd:"onready=Shop/Card%d"``: a FIXED ARRAY of
// handles (or `[N]^script struct`) with an INDEXED path template. `count` > 0 marks it;
// `path` then contains exactly one `%d` (walk-validated), substituted with 0-based
// indices at resolve time. Elements are pointer-sized, laid out contiguously from
// `offset`. count == 0 is the scalar form above.
Onready :: struct {
	offset:       uintptr,
	path:         cstring,
	field:        cstring,
	script_id:    typeid,
	script_class: cstring,
	count:        i32,
}

// The uniform trampoline a custom method is invoked through. GDScript-initiated
// calls arrive as Variants, so `args`/`ret` are VariantPtr. The author writes a
// small wrapper that unpacks Variants -> typed params, runs logic, and writes the
// return Variant (codegen will auto-emit these later).
Method_Proc :: proc "c" (self: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr)

// A callable custom method (from GDScript and cross-script).
Method :: struct {
	name:            cstring,
	trampoline:      Method_Proc,
	arg_types:       [^]gdext.Variant_Type,
	arg_types_count: i32,
	return_type:     gdext.Variant_Type, // .Nil for void
}

// A declared signal. `arg_names`/`arg_types` describe the payload (parallel arrays).
Signal :: struct {
	name:            cstring,
	arg_names:       [^]cstring,
	arg_names_count: i32,
	arg_types:       [^]gdext.Variant_Type,
	arg_types_count: i32,
}

// A declarative signal connection (from `@(gd_connect="signal")` on a method): on the
// node's READY, the core connects owner.`signal` -> owner.`method`, so the author needn't
// write a `ready` proc just to wire a signal.
//
// PATH-QUALIFIED form — `@(gd_connect="Path/To/Node:signal")`: `path` names the EMITTER
// node (owner-relative, absolute, or `..`-style — anything get_node takes), resolved at
// READY exactly like an `onready=` ref, then emitter.`signal` -> owner.`method`. nil
// `path` = the plain form above (the owner emits its own signal). scriptgen splits the
// declaration at the LAST ':' (node names cannot contain ':'), so only the split parts
// cross the boundary here.
//
// INDEXED form — `@(gd_connect="Panel/Choice%d:pressed")` (`indexed` set, `path` holds
// exactly one `%d`): the core probes indices 0, 1, 2, … until a node is missing and
// connects EACH match with its index BOUND as a trailing callable arg — one handler for
// N sibling emitters, told apart by its trailing index parameter. Index 0 must exist
// (loud error otherwise).
Connection :: struct {
	signal:  cstring,
	method:  cstring,
	path:    cstring,
	indexed: bool,
}

// An `@(gd_rpc)` declaration on a `@(gd_method)` proc: the method is exposed to Godot's
// high-level multiplayer (`node.rpc("method", ...)` / incoming remote calls). The core
// reports this config to the engine via `ScriptExtension._get_rpc_config`, after which the
// engine routes RPCs to the method through the SAME `inst_call` path a normal call uses.
//   - `method`     is the GDScript-exposed method name (the `@(gd_method)` gd_name).
//   - `mode`       is a `MultiplayerAPI.RPCMode` int (ANY_PEER=1, AUTHORITY=2).
//   - `transfer`   is a `MultiplayerPeer.TransferMode` int (UNRELIABLE=0,
//                  UNRELIABLE_ORDERED=1, RELIABLE=2).
//   - `call_local` => the RPC ALSO runs on the local/calling peer.
//   - `channel`    is the transfer channel (0 default).
// The ints are stored verbatim so they drop straight into the engine's config Dictionary.
Rpc :: struct {
	method:     cstring,
	mode:       i64,
	transfer:   i64,
	call_local: bool,
	channel:    i64,
}

// A registered Odin script class. `size`/`align` describe the script's own struct
// (whose FIRST field is, by convention, the owner Object pointer) so the core can
// allocate + zero an instance. `exports`/`methods`/`signals` are Phase 3 member
// surfaces: C-shaped pointer+count pairs referencing static arrays in the scripts dll
// (dll-lifetime; an empty table is nil + 0). The whole struct is strict C-compatible
// data — no Odin slices/multi-returns cross the dll boundary (see desc_exports & co.
// for the per-side slice views).
Class_Desc :: struct {
	name:      cstring,
	base:      cstring,
	// The script struct's Odin `typeid` (e.g. `typeid_of(Enemy)`). An OPAQUE pointer-sized
	// token to the core: used SOLELY inside the scripts dll to map a compile-time type `T`
	// back to its registered class name for `rt.script_of(obj, T)`'s class check (see
	// cross.odin / class_name_for_typeid). The CORE never interprets or dereferences it
	// (typeids are not stable across the core/scripts dll boundary); it is only ever
	// compared within the one dll that registered it. Zero for a class that does not
	// participate in typed cross-script lookups.
	id:        typeid,
	size:      int,
	align:     int,
	lifecycle: Lifecycle,
	exports:           [^]Export,
	exports_count:     i32,
	methods:           [^]Method,
	methods_count:     i32,
	signals:           [^]Signal,
	signals_count:     i32,
	connections:       [^]Connection,
	connections_count: i32,
	onready:           [^]Onready,
	onready_count:     i32,
	// `//gd:group a b` — groups the core joins on the node's READY (before onready /
	// connection wiring / the user's ready). Static cstrings, dll-lifetime.
	groups:            [^]cstring,
	groups_count:      i32,
	// `@(gd_rpc)` method RPC configs — reported to the engine via `_get_rpc_config`.
	rpcs:              [^]Rpc,
	rpcs_count:        i32,
	tool:        bool,
	// `//gd:icon <res-path>` — custom class icon shown in the editor (Scene dock,
	// Create Node/Resource dialogs). Empty => no custom icon.
	icon:        cstring,
	// `///` doc comment above the script struct (class description for the editor doc panel,
	// via `_get_documentation`). nil/"" == none.
	doc:         cstring,
}

// ----------------------------------------------------------------------------
// Slice views over the C-shaped tables above. The BOUNDARY carries raw
// pointer+count pairs; these contextless helpers are a per-side convenience
// (compiled into whichever module uses them) and never cross the dll boundary.
// A nil table views as an empty slice.
// ----------------------------------------------------------------------------
desc_exports :: proc "contextless" (d: Class_Desc) -> []Export {
	return d.exports[:d.exports_count]
}
desc_methods :: proc "contextless" (d: Class_Desc) -> []Method {
	return d.methods[:d.methods_count]
}
desc_signals :: proc "contextless" (d: Class_Desc) -> []Signal {
	return d.signals[:d.signals_count]
}
desc_connections :: proc "contextless" (d: Class_Desc) -> []Connection {
	return d.connections[:d.connections_count]
}
desc_onready :: proc "contextless" (d: Class_Desc) -> []Onready {
	return d.onready[:d.onready_count]
}
desc_groups :: proc "contextless" (d: Class_Desc) -> []cstring {
	return d.groups[:d.groups_count]
}
desc_rpcs :: proc "contextless" (d: Class_Desc) -> []Rpc {
	return d.rpcs[:d.rpcs_count]
}
method_arg_types :: proc "contextless" (m: Method) -> []gdext.Variant_Type {
	return m.arg_types[:m.arg_types_count]
}
signal_arg_names :: proc "contextless" (s: Signal) -> []cstring {
	return s.arg_names[:s.arg_names_count]
}
signal_arg_types :: proc "contextless" (s: Signal) -> []gdext.Variant_Type {
	return s.arg_types[:s.arg_types_count]
}

// Scripts-dll-local registry. A FIXED-SIZE array (not a [dynamic]) so `register`
// needs no allocator/context — it runs from `@(init)` on dlopen, before the core
// has booted this dll's gdext/godot globals (and thus before any allocator setup).
MAX_CLASSES :: 256

@(private)
registry: [MAX_CLASSES]Class_Desc
@(private)
registry_count: int

// Called by each script's `@(init)` to publish its class to the scripts dll.
//
// DUPLICATE CLASS NAMES — keep-first + a recorded Registration_Error (never silent,
// never last-write-wins). Names are compared by VALUE: every module compiles its own
// cstring literals, so pointer comparison would miss every real collision. Semantics
// by target:
//   * NATIVE: each scripts dll has its OWN registry, so a duplicate here is a
//     SAME-module authoring error (two structs claiming one class name). The
//     CROSS-module collision is still caught by the core's index_module_manifest,
//     which loads dlls one at a time and can name both modules.
//   * WEB: all script modules link into ONE wasm and share THIS registry, so this
//     check IS the cross-module collision check (the core's class index would
//     otherwise silently last-write-wins). Keep-first mirrors native's
//     reject-the-later-module semantics.
// LIMITATION: the registry has no module attribution (`register` runs from `@(init)`,
// before any module identity exists), so the error can name the CLASS but not which
// two modules collided. The error surfaces through the same drain as every other
// registration error (odin_scripts_registration_errors -> the core's push_error pass).
register :: proc "contextless" (desc: Class_Desc) {
	if desc.name != nil {
		for i in 0 ..< registry_count {
			if registry[i].name != nil && string(registry[i].name) == string(desc.name) {
				record_error(
					desc.name,
					nil,
					"duplicate class registration — this class name is already registered; the LATER registration is DROPPED (first wins). In one module this means two structs claim the same class name; on web (all script modules share one registry) it can also be a cross-module collision (module names are not known here — check scripts/ and each modules/<name>/)",
				)
				return
			}
		}
	}
	if registry_count >= MAX_CLASSES {
		record_error(
			desc.name,
			nil,
			"script class registry is full (maximum 256 classes in one scripts DLL) — this class was DROPPED; split the project into script modules or increase MAX_CLASSES and rebuild the addon",
		)
		return
	}
	registry[registry_count] = desc
	registry_count += 1
}

// Resolve a script struct's `typeid` to its registered class name (the cstring the core
// stored in `Odin_Instance.class_name`). Returns nil when `id` is not a registered class —
// which makes `rt.script_of(obj, T)` safely return nil for a `T` that is not an Odin script
// class. Walked linearly (registry_count is tiny: one entry per script class); a zero `id`
// never matches a real registration, so it cannot alias an unset Class_Desc.id. Contextless +
// allocation-free so `script_of` stays cheap on the per-shot/per-frame hot path.
class_name_for_typeid :: proc "contextless" (id: typeid) -> cstring {
	if id == nil {
		return nil
	}
	for i in 0 ..< registry_count {
		if registry[i].id == id {
			return registry[i].name
		}
	}
	return nil
}

// The reverse: a registered class NAME to its script struct typeid. Compared by VALUE —
// the name arrives as core-owned bytes (an Odin_Instance's heap copy), never this dll's
// static cstring, so pointer identity would always miss. nil when no class of that name
// is registered HERE, which is what keeps `rt.script_any` module-safe: a foreign module's
// class name misses this registry and resolves to nothing. Same linear walk / cost story
// as class_name_for_typeid above.
typeid_for_class_name :: proc "contextless" (name: string) -> typeid {
	if name == "" {
		return nil
	}
	for i in 0 ..< registry_count {
		if string(registry[i].name) == name {
			return registry[i].id
		}
	}
	return nil
}

// The core pulls this right after `odin_scripts_boot`, dlsym'd by name, to learn
// which classes the scripts dll provides. C-shaped: out-param count + returned
// pointer (no Odin multi-return across the dll boundary).
//
// Also the earliest every-`@(init)`-has-run hook, so the script-onready fixup lives
// here (once): each `^<script struct>` onready entry's typeid resolves to its
// registered class name NOW, which mid-walk registration order made impossible.
// Runs before the core's registration-errors drain on both native and web, so a
// bad target surfaces through the normal error pass.
@(private)
onready_fixup_done: bool

@(export)
odin_scripts_manifest :: proc "c" (out_count: ^i32) -> [^]Class_Desc {
	if !onready_fixup_done {
		onready_fixup_done = true
		fixup_onready_script_targets()
	}
	if out_count != nil {
		out_count^ = i32(registry_count)
	}
	return raw_data(registry[:])
}

// ABI version of the core<->scripts data contract (the structs above, read across the dll
// boundary). The core dlsym's this right after boot and REFUSES to read the manifest on a
// mismatch — so updating the addon's prebuilt core but forgetting to rebuild your scripts dll
// (or vice-versa) fails with a clear "rebuild" message instead of reading Class_Desc at the
// wrong field offsets (bogus sizes -> undersized allocs -> heap corruption; stale proc ptrs
// -> jumps into garbage). Auto-derived from the shared struct sizes so adding/removing a field
// bumps it automatically; ABI_GENERATION is a manual bump for layout changes size_of can't see
// (e.g. reordering Class_Desc's fields).
//
// The sizes are folded with FNV-1a (each size is one "symbol": xor then multiply by the FNV
// prime, masked to 32 bits so the untyped-constant arithmetic never overflows). The previous
// scheme XOR'd shifted sizes together, and XOR terms can CANCEL — two offsetting size changes
// (or one struct growing by exactly what another shrank, at colliding shift positions) yielded
// the SAME version for a different layout. FNV-1a's multiply makes the fold order- and
// position-sensitive, so any single size change always changes the version.
// Generation 2: the C-shaped ABI — slices became pointer+count pairs and
// odin_scripts_manifest's multi-return became an out-param (a signature change the
// size fold below cannot see).
ABI_GENERATION :: 2
@(private) ABI_FNV_PRIME :: 16777619
@(private) ABI_H0 :: ((2166136261 ~ ABI_GENERATION)        * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H1 :: ((ABI_H0 ~ size_of(Class_Desc))       * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H2 :: ((ABI_H1 ~ size_of(Lifecycle))        * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H3 :: ((ABI_H2 ~ size_of(Export))           * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H4 :: ((ABI_H3 ~ size_of(Method))           * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H5 :: ((ABI_H4 ~ size_of(Signal))           * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H6 :: ((ABI_H5 ~ size_of(Onready))          * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H7 :: ((ABI_H6 ~ size_of(Connection))       * ABI_FNV_PRIME) & 0xFFFF_FFFF
@(private) ABI_H8 :: ((ABI_H7 ~ size_of(Rpc))              * ABI_FNV_PRIME) & 0xFFFF_FFFF
// Registration_Error crosses the boundary too (odin_scripts_registration_errors).
@(private) ABI_H9 :: ((ABI_H8 ~ size_of(Registration_Error)) * ABI_FNV_PRIME) & 0xFFFF_FFFF
ABI_VERSION :: u32(ABI_H9)

@(export)
odin_scripts_abi_version :: proc "c" () -> u32 {
	return ABI_VERSION
}

// Compiler-skew handshake, companion to the ABI version above. Same struct SIZES do not
// guarantee the same layout/calling conventions across Odin compiler releases, so the core
// also compares the compiler that built the scripts dll against its own ODIN_VERSION and
// refuses the manifest on a mismatch ("rebuild your scripts"). Pure data — safe to call
// before boot. A dll built before this symbol existed dlsyms to nil, which the core treats
// as a mismatch too (never a crash).
@(export)
odin_scripts_odin_version :: proc "c" () -> cstring {
	return ODIN_VERSION
}
