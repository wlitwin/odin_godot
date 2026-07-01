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
Onready :: struct {
	offset: uintptr,
	path:   cstring,
}

// The uniform trampoline a custom method is invoked through. GDScript-initiated
// calls arrive as Variants, so `args`/`ret` are VariantPtr. The author writes a
// small wrapper that unpacks Variants -> typed params, runs logic, and writes the
// return Variant (codegen will auto-emit these later).
Method_Proc :: proc "c" (self: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr)

// A callable custom method (from GDScript and cross-script).
Method :: struct {
	name:        cstring,
	trampoline:  Method_Proc,
	arg_types:   []gdext.Variant_Type,
	return_type: gdext.Variant_Type, // .Nil for void
}

// A declared signal. `arg_names`/`arg_types` describe the payload (parallel arrays).
Signal :: struct {
	name:      cstring,
	arg_names: []cstring,
	arg_types: []gdext.Variant_Type,
}

// A declarative signal connection (from `@(gd_connect="signal")` on a method): on the
// node's READY, the core connects owner.`signal` -> owner.`method`, so the author needn't
// write a `ready` proc just to wire a signal.
Connection :: struct {
	signal: cstring,
	method: cstring,
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
// surfaces; their slices point at static arrays in the scripts dll.
Class_Desc :: struct {
	name:      cstring,
	base:      cstring,
	// The script struct's Odin `typeid` (e.g. `typeid_of(Enemy)`). Used SOLELY inside the
	// scripts dll to map a compile-time type `T` back to its registered class name for
	// `rt.script_of(obj, T)`'s class check (see cross.odin / class_name_for_typeid). The CORE
	// never interprets this (typeids are not stable across the core/scripts dll boundary); it
	// is only ever compared within the one dll that registered it. Zero for a class that does
	// not participate in typed cross-script lookups.
	id:        typeid,
	size:      int,
	align:     int,
	lifecycle: Lifecycle,
	exports:     []Export,
	methods:     []Method,
	signals:     []Signal,
	connections: []Connection,
	onready:     []Onready,
	// `@(gd_rpc)` method RPC configs — reported to the engine via `_get_rpc_config`.
	rpcs:        []Rpc,
	tool:        bool,
	// `//gd:icon <res-path>` — custom class icon shown in the editor (Scene dock,
	// Create Node/Resource dialogs). Empty => no custom icon.
	icon:        cstring,
	// `///` doc comment above the script struct (class description for the editor doc panel,
	// via `_get_documentation`). nil/"" == none.
	doc:         cstring,
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
register :: proc "contextless" (desc: Class_Desc) {
	if registry_count >= MAX_CLASSES {
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

// The core pulls this right after `odin_scripts_boot`, dlsym'd by name, to learn
// which classes the scripts dll provides.
@(export)
odin_scripts_manifest :: proc "c" () -> (descs: [^]Class_Desc, count: int) {
	return raw_data(registry[:]), registry_count
}

// ABI version of the core<->scripts data contract (the structs above, read across the dll
// boundary). The core dlsym's this right after boot and REFUSES to read the manifest on a
// mismatch — so updating the addon's prebuilt core but forgetting to rebuild your scripts dll
// (or vice-versa) fails with a clear "rebuild" message instead of reading Class_Desc at the
// wrong field offsets (bogus sizes -> undersized allocs -> heap corruption; stale proc ptrs
// -> jumps into garbage). Auto-derived from the shared struct sizes so adding/removing a field
// bumps it automatically; ABI_GENERATION is a manual bump for layout changes size_of can't see
// (e.g. reordering Class_Desc's fields).
ABI_GENERATION :: u32(1)
ABI_VERSION :: ABI_GENERATION ~
	u32(size_of(Class_Desc)) ~
	(u32(size_of(Lifecycle)) << 8) ~
	(u32(size_of(Export)) << 16) ~
	(u32(size_of(Method)) << 5) ~
	(u32(size_of(Signal)) << 13) ~
	(u32(size_of(Onready)) << 21) ~
	(u32(size_of(Connection)) << 3) ~
	(u32(size_of(Rpc)) << 11)

@(export)
odin_scripts_abi_version :: proc "c" () -> u32 {
	return ABI_VERSION
}
