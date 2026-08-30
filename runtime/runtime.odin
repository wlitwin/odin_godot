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
	// still point at the OLD code until this hook refreshes them. Authored as `<class>_reload`.
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
	size:        uintptr,
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
	has_default: b8,
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
// it is DLL-LOCAL and opaque to the core. The walk cannot resolve it to a source identity
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
	// Scripts-DLL-local `typeid`, carried as an opaque 64-bit token while the
	// registry performs its pre-publication fixup. The core never interprets it.
	script_id:    u64,
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
	indexed: b8,
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
	call_local: b8,
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
	// Human-readable Odin struct name, used for diagnostics and editor docs. It is
	// not an identity: two packages may legitimately declare the same struct name.
	name:      cstring,
	// Canonical authored-resource identity (`res://.../file.odin`). Generated
	// descriptors always provide it; hand-written/legacy descriptors fall back to name.
	path:      cstring,
	// Optional explicit `//gd:class` alias. Only this name enters Godot's global class
	// namespace; marker-less scripts remain fully attachable through `path`.
	global_name: cstring,
	base:      cstring,
	// The script struct's Odin `typeid` (e.g. `typeid_of(Enemy)`), encoded as an OPAQUE
	// 64-bit token. It is used SOLELY inside the scripts dll to map a compile-time type `T`
	// back to its registered source identity for `rt.script_of(obj, T)`'s check (see
	// cross.odin / identity_for_typeid). The CORE never interprets or dereferences it
	// (typeids are not stable across the core/scripts dll boundary); it is only ever
	// compared within the one dll that registered it. Zero for a class that does not
	// participate in typed cross-script lookups.
	id:        u64,
	size:      uintptr,
	align:     uintptr,
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
	tool:        b8,
	// True when the script struct can retain code-generation-bound state: a typed
	// procedure value (including one nested in arrays, maps, unions, Event/Action-style
	// containers) or an opaque rawptr. The core only rebinds such live state when the
	// new descriptor supplies a reload hook that explicitly rebuilds those references.
	generation_bound_state: b8,
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

// Stable identity used for runtime maps, typed script checks, and hot reload. The
// fallback keeps the reflection unit surface and hand-written descriptors working.
desc_identity :: proc "contextless" (d: Class_Desc) -> cstring {
	if d.path != nil && string(d.path) != "" {
		return d.path
	}
	return d.name
}

// Scripts-dll-local registry. Registrations run sequentially during the `@(init)`
// chain and the manifest is not exposed until that chain has completed, so this can
// grow without invalidating a pointer already held by the core. `script_context`
// provides the native heap allocator during dlopen; on web, `web_startup` installs
// the engine-backed allocator hook before it starts the same init chain.
//
// There is deliberately no authored-class ceiling: capacity grows with the project
// and is bounded only by available memory (the C-shaped manifest count remains i32).
@(private)
registry: [dynamic]Class_Desc

// Called by each script's `@(init)` to publish its class to the scripts dll.
//
// Duplicate SOURCE identities keep the first descriptor and record an error. Optional
// global aliases are not identity and are intentionally allowed through this low-level
// registry: the core sees the complete manifest and can diagnose an alias collision with
// both authored paths (including across composed web modules).
register :: proc "contextless" (desc: Class_Desc) {
	context = script_context()
	identity := desc_identity(desc)
	if identity != nil {
		for i in 0 ..< len(registry) {
			other := desc_identity(registry[i])
			if other != nil && string(other) == string(identity) {
				record_error(
					desc.name,
					nil,
					"duplicate script source identity — this res:// path is already registered; the LATER registration is DROPPED (first wins)",
				)
				return
			}
		}
	}
	if registry == nil {
		registry = make([dynamic]Class_Desc, 0, 32)
	}
	append(&registry, desc)
}

// Resolve a script struct's `typeid` to its registered source identity (the cstring the
// core stores on Odin_Instance). Returns nil when `id` is not a registered class —
// which makes `rt.script_of(obj, T)` safely return nil for a `T` that is not an Odin script
// class. Walked linearly (the registry is typically tiny: one entry per script class); a zero `id`
// never matches a real registration, so it cannot alias an unset Class_Desc.id. Contextless +
// allocation-free so `script_of` stays cheap on the per-shot/per-frame hot path.
identity_for_typeid :: proc "contextless" (id: typeid) -> cstring {
	if id == nil {
		return nil
	}
	token := transmute(u64)id
	for i in 0 ..< len(registry) {
		if registry[i].id == token {
			return desc_identity(registry[i])
		}
	}
	return nil
}

// The reverse: a registered source identity to its script struct typeid. Compared by VALUE —
// the identity arrives as core-owned bytes, never this dll's static cstring, so pointer
// identity would always miss. nil when no class of that identity
// is registered HERE, which is what keeps `rt.script_any` module-safe: a foreign module's
// source identity misses this registry and resolves to nothing. Same linear walk / cost story
// as identity_for_typeid above.
typeid_for_identity :: proc "contextless" (identity: string) -> typeid {
	if identity == "" {
		return nil
	}
	for i in 0 ..< len(registry) {
		candidate := desc_identity(registry[i])
		if candidate != nil && string(candidate) == identity {
			return transmute(typeid)registry[i].id
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
// registered source identity NOW, which mid-walk registration order made impossible.
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
		out_count^ = i32(len(registry))
	}
	return raw_data(registry[:])
}

// ABI handshake for the core<->scripts contract. ABI_VERSION is the deliberately bumped
// semantic generation (function signatures/meaning); abi_layout_fingerprint is computed on
// each side from every public struct's size, alignment, and NAMED field offsets plus the
// primitive/procedure representations used by the boundary. A compiler release is therefore
// compatible only when it produced the exact same boundary layout. The fingerprint runs once
// while loading a DLL; it adds no dispatch, allocation, or per-frame cost.
//
// Boundary values use C call conventions, cstrings, fixed-width integers, address-width
// uintptrs, b8 flags, and pointer+count tables. `typeid` remains part of the authored/runtime
// API but crosses only as an opaque u64 token that is resolved inside the scripts DLL.
// Neither DLL frees memory owned by the other.
// Generation 2: the C-shaped ABI — slices became pointer+count pairs and
// odin_scripts_manifest's multi-return became an out-param (a signature change the
// layout fingerprint cannot infer).
// Generation 3: Class_Desc gained generation_bound_state in what may otherwise be
// padding, so a semantic bump was required by the old size-only hash.
// Generation 4: fixed-width metadata plus the complete layout-fingerprint export; exact
// compiler-version equality is diagnostic rather than the compatibility gate.
ABI_GENERATION :: 4
ABI_VERSION :: u32(ABI_GENERATION)

@(private = "file")
abi_mix :: proc "contextless" (h: ^u64, value: uintptr) {
	h^ = (h^ ~ u64(value)) * 1099511628211
}

// Keep the order stable. Adding/reordering a boundary field changes at least one aggregate
// size or named offset; changing a signature/meaning still requires ABI_GENERATION to move.
abi_layout_fingerprint :: proc "contextless" () -> u64 {
	h := u64(14695981039346656037)
	mix :: proc "contextless" (h: ^u64, values: ..uintptr) {
		for value in values {abi_mix(h, value)}
	}

	mix(&h, ABI_GENERATION)
	mix(&h,
		size_of(rawptr), align_of(rawptr), size_of(cstring), align_of(cstring),
		size_of(uintptr), align_of(uintptr), size_of(i32), align_of(i32),
		size_of(i64), align_of(i64), size_of(u32), align_of(u32),
		size_of(u64), align_of(u64), size_of(f64), align_of(f64),
		size_of(b8), align_of(b8), size_of(gdext.Variant_Type), align_of(gdext.Variant_Type),
		size_of(Method_Proc), align_of(Method_Proc),
	)

	mix(&h, size_of(Lifecycle), align_of(Lifecycle),
		offset_of(Lifecycle, ready), offset_of(Lifecycle, enter_tree),
		offset_of(Lifecycle, exit_tree), offset_of(Lifecycle, process),
		offset_of(Lifecycle, physics_process), offset_of(Lifecycle, reload))
	mix(&h, size_of(Export), align_of(Export),
		offset_of(Export, name), offset_of(Export, type), offset_of(Export, offset),
		offset_of(Export, size), offset_of(Export, hint), offset_of(Export, hint_string),
		offset_of(Export, group), offset_of(Export, subgroup), offset_of(Export, has_default),
		offset_of(Export, default_num), offset_of(Export, default_str),
		offset_of(Export, getter), offset_of(Export, setter), offset_of(Export, line),
		offset_of(Export, doc))
	mix(&h, size_of(Onready), align_of(Onready),
		offset_of(Onready, offset), offset_of(Onready, path), offset_of(Onready, field),
		offset_of(Onready, script_id), offset_of(Onready, script_class), offset_of(Onready, count))
	mix(&h, size_of(Method), align_of(Method),
		offset_of(Method, name), offset_of(Method, trampoline), offset_of(Method, arg_types),
		offset_of(Method, arg_types_count), offset_of(Method, return_type))
	mix(&h, size_of(Signal), align_of(Signal),
		offset_of(Signal, name), offset_of(Signal, arg_names), offset_of(Signal, arg_names_count),
		offset_of(Signal, arg_types), offset_of(Signal, arg_types_count))
	mix(&h, size_of(Connection), align_of(Connection),
		offset_of(Connection, signal), offset_of(Connection, method), offset_of(Connection, path),
		offset_of(Connection, indexed))
	mix(&h, size_of(Rpc), align_of(Rpc),
		offset_of(Rpc, method), offset_of(Rpc, mode), offset_of(Rpc, transfer),
		offset_of(Rpc, call_local), offset_of(Rpc, channel))
	mix(&h, size_of(Class_Desc), align_of(Class_Desc),
		offset_of(Class_Desc, name), offset_of(Class_Desc, path),
		offset_of(Class_Desc, global_name), offset_of(Class_Desc, base),
		offset_of(Class_Desc, id), offset_of(Class_Desc, size), offset_of(Class_Desc, align),
		offset_of(Class_Desc, lifecycle), offset_of(Class_Desc, exports),
		offset_of(Class_Desc, exports_count), offset_of(Class_Desc, methods),
		offset_of(Class_Desc, methods_count), offset_of(Class_Desc, signals),
		offset_of(Class_Desc, signals_count), offset_of(Class_Desc, connections),
		offset_of(Class_Desc, connections_count), offset_of(Class_Desc, onready),
		offset_of(Class_Desc, onready_count), offset_of(Class_Desc, groups),
		offset_of(Class_Desc, groups_count), offset_of(Class_Desc, rpcs),
		offset_of(Class_Desc, rpcs_count), offset_of(Class_Desc, tool),
		offset_of(Class_Desc, generation_bound_state), offset_of(Class_Desc, icon),
		offset_of(Class_Desc, doc))
	// Registration_Error crosses through odin_scripts_registration_errors too.
	mix(&h, size_of(Registration_Error), align_of(Registration_Error),
		offset_of(Registration_Error, class), offset_of(Registration_Error, field),
		offset_of(Registration_Error, msg))
	return h
}

@(export)
odin_scripts_abi_version :: proc "c" () -> u32 {
	return ABI_VERSION
}

@(export)
odin_scripts_abi_fingerprint :: proc "c" () -> u64 {
	return abi_layout_fingerprint()
}

// Compiler identity is retained for diagnostics and build provenance. Compatibility is
// decided by ABI_VERSION + the complete layout fingerprint above, not this string.
@(export)
odin_scripts_odin_version :: proc "c" () -> cstring {
	return ODIN_VERSION
}
