package core

import "godot:gdext"
import "godot:godot"
import rt "godot:runtime"

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:sync"

// ----------------------------------------------------------------------------
// Real per-node script instances — the compiled-dispatch heart (Phase 2).
//
// When the engine attaches an OdinScript to an owner node it calls
// `OdinScript._instance_create(owner)`, which builds a `GDExtensionScriptInstanceInfo3`
// instance via `script_instance_create3`. Engine lifecycle/method calls then enter
// Odin through that vtable:
//   - notification_func: NOTIFICATION_READY/ENTER_TREE/EXIT_TREE -> lifecycle procs
//     (**_ready arrives as a NOTIFICATION, not a call**).
//   - call_func: `_process`/`_physics_process` (after set_process/set_physics_process)
//     -> lifecycle procs. Unknown methods get INVALID_METHOD so engine built-ins work.
// ----------------------------------------------------------------------------

// Godot Node notification constants.
NOTIFICATION_ENTER_TREE :: 10
NOTIFICATION_EXIT_TREE :: 11
NOTIFICATION_READY :: 13

// Per-instance state. A pointer to this is the `ExtensionScriptInstanceDataPtr` the
// engine hands back to every vtable callback.
@(private)
Odin_Instance :: struct {
	owner:      gdext.ObjectPtr,
	script:     gdext.ObjectPtr, // the OdinScript object
	desc:       rt.Class_Desc,
	user:       rawptr, // the allocated script struct (owner ptr at offset 0)
	cache:      ^Class_Cache, // interned names + cached Variant constructors (per class)
	class_name: string, // OWNED (heap) copy of desc.name — survives a dll swap (Phase 4)
}

// ----------------------------------------------------------------------------
// Phase 4 — live-instance registry for hot reload.
//
// Every real script instance is tracked here so that, on a scripts-dll swap, the
// core can walk all live instances and re-bind them to the NEW Class_Desc/proc ptrs
// BEFORE any further engine callback can fire a stale (dangling) proc. The `owner`
// Godot Object is never recreated — only the Odin-side desc/cache/struct binding.
// ----------------------------------------------------------------------------
@(private)
live_instances: [dynamic]^Odin_Instance

// owner -> its live instance, the O(1) lookup behind odin_script_struct. Maintained in
// lockstep with live_instances, under live_lock.
@(private)
live_by_owner: map[gdext.ObjectPtr]^Odin_Instance

// Guards ALL access to live_instances/live_by_owner: Godot can create/free script
// instances on worker threads (threaded resource loads), and odin_script_struct is
// reachable from arbitrary script code via rt.script_of. NON-recursive — never call
// into Godot or script code while holding it.
@(private)
live_lock: sync.Mutex

@(private)
track_live_instance :: proc(oi: ^Odin_Instance) {
	context.allocator = core_allocator()
	sync.lock(&live_lock)
	defer sync.unlock(&live_lock)
	append(&live_instances, oi)
	if live_by_owner == nil {
		live_by_owner = make(map[gdext.ObjectPtr]^Odin_Instance)
	}
	live_by_owner[oi.owner] = oi
}

@(private)
untrack_live_instance :: proc(oi: ^Odin_Instance) {
	context.allocator = core_allocator()
	sync.lock(&live_lock)
	defer sync.unlock(&live_lock)
	for x, i in live_instances {
		if x == oi {
			unordered_remove(&live_instances, i)
			break
		}
	}
	if x, ok := live_by_owner[oi.owner]; ok && x == oi {
		delete_key(&live_by_owner, oi.owner)
	}
}

// Clone a string onto the Odin heap allocator (the godot allocator ignores
// alignment; core-owned bookkeeping must use the heap allocator).
@(private)
heap_clone :: proc(s: string) -> string {
	context.allocator = core_allocator()
	return strings.clone(s)
}

@(private)
heap_delete_string :: proc(s: string) {
	if s == "" {return}
	context.allocator = core_allocator()
	delete(s)
}

// ----------------------------------------------------------------------------
// Per-class cache. The runtime Class_Desc gives us cstrings + Variant types, but the
// hot vtable callbacks (`set`/`get`/`call`) are `proc "c"` and want to compare against
// interned StringNames and call cached Variant constructors WITHOUT allocating per
// call. We build this once per class (lazily, when the first instance is created — at
// which point gdext is booted) and share it across that class's instances.
// ----------------------------------------------------------------------------

@(private)
Export_Cache :: struct {
	name:        godot.String_Name,
	type:        gdext.Variant_Type,
	offset:      uintptr,
	size:        int,
	hint:        i64, // godot.Property_Hint int value (0 == None)
	hint_string: godot.String, // companion string for the hint (interned once per class)
	// Typed-collection element info, parsed from a Type_String hint (hint 23 on an
	// Array/Dictionary export: "2:" builtin / "24/17:Class" Resource / "K;V" dict).
	// Drives seed_container_field: a freshly-zeroed gd.Array/gd.Dictionary is NOT a
	// valid engine value, so instances are seeded with real empty containers, typed
	// per the hint. key_* are the Dictionary KEY (unused for Arrays).
	elem_type:  gdext.Variant_Type, // Array element / Dictionary VALUE
	elem_class: godot.String_Name,
	key_type:   gdext.Variant_Type,
	key_class:  godot.String_Name,
	to_type:     gdext.TypeFromVariantConstructorProc, // Variant -> field
	from_type:   gdext.VariantFromTypeConstructorProc, // field   -> Variant
	// Destructor for the field's engine value (nil for POD types and .Object — see
	// destruct_export_field). Cached here: inst_set is a hot vtable path.
	dtor:        gdext.PtrDestructor,
	// group/subgroup header to emit before this property (richer-authoring #2).
	group:        godot.String_Name,
	has_group:    bool,
	subgroup:     godot.String_Name,
	has_subgroup: bool,
	// default value (richer-authoring #3): interned once per class as a Variant.
	has_default: bool,
	default:     godot.Variant,
	// getter/setter wrappers (richer-authoring #4); nil => plain field access.
	getter:      proc "c" (self: rawptr, ret: gdext.VariantPtr),
	setter:      proc "c" (self: rawptr, value: gdext.VariantPtr),
}

@(private)
Class_Cache :: struct {
	exports:           []Export_Cache,
	method_names:      []godot.String_Name, // parallels desc.methods
	// name -> index into exports / method_names, so the per-call vtable hot paths
	// (inst_set/inst_get/inst_call) are a map probe, not a linear scan. Keyed by the
	// interned String_Name's raw bits (see sn_bits).
	export_index:      map[uintptr]int,
	method_index:      map[uintptr]int,
	empty_string:      godot.String,
	empty_string_name: godot.String_Name,
}

// A String_Name's raw bits as a map key. StringNames are engine-interned: equal names
// share one handle, so bit equality IS name equality — the same invariant the `==`
// comparisons throughout this file rely on. (String_Name is one uintptr wide.)
@(private)
sn_bits :: #force_inline proc "contextless" (n: godot.String_Name) -> uintptr {
	return transmute(uintptr)n
}

// class name -> its built cache. Keyed by the Class_Desc.name cstring (string view).
@(private)
class_caches: map[string]^Class_Cache

@(private)
ensure_class_cache :: proc(desc: rt.Class_Desc) -> ^Class_Cache {
	// Core-owned bookkeeping must live on the Odin heap allocator (Godot's mem_alloc
	// ignores alignment; Odin maps assert cache-line alignment).
	context.allocator = core_allocator()

	if class_caches == nil {
		class_caches = make(map[string]^Class_Cache)
	}
	key := string(desc.name)
	if existing, ok := class_caches[key]; ok {
		return existing
	}

	cache := new(Class_Cache)
	cache.empty_string = godot.new_string_cstring("")
	cache.empty_string_name = godot.new_string_name_cstring("", true)

	exports := rt.desc_exports(desc)
	cache.exports = make([]Export_Cache, len(exports))
	for ex, i in exports {
		cache.exports[i] = Export_Cache {
			name        = godot.new_string_name_cstring(ex.name, true),
			type        = ex.type,
			offset      = ex.offset,
			size        = ex.size,
			hint        = ex.hint,
			hint_string = godot.new_string_cstring(ex.hint_string == nil ? "" : ex.hint_string),
			to_type     = gdext.get_variant_to_type_constructor(ex.type),
			from_type   = gdext.get_variant_from_type_constructor(ex.type),
			dtor        = (ex.type == .Object || ex.type == .Nil) ? nil : gdext.variant_get_ptr_destructor(ex.type),
			has_group    = ex.group != nil,
			group        = godot.new_string_name_cstring(ex.group == nil ? "" : ex.group, true),
			has_subgroup = ex.subgroup != nil,
			subgroup     = godot.new_string_name_cstring(ex.subgroup == nil ? "" : ex.subgroup, true),
			has_default  = ex.has_default,
			default      = export_default_variant(ex),
			getter       = ex.getter,
			setter       = ex.setter,
		}
		// Typed Array/Dictionary: recover the element Variant type (+ Resource class)
		// from the registration hint_string so seed_container_field can construct
		// correctly-TYPED empty containers (the engine's scene-load conversion asks the
		// property for its current typed value before setting it).
		ec := &cache.exports[i]
		ec.elem_class = cache.empty_string_name
		ec.key_class = cache.empty_string_name
		if ec.hint == i64(godot.Property_Hint.Type_String) && ex.hint_string != nil {
			hs := string(ex.hint_string)
			#partial switch ec.type {
			case .Array:
				ec.elem_type, ec.elem_class = parse_type_string_part(hs, cache.empty_string_name)
			case .Dictionary:
				if semi := strings.index_byte(hs, ';'); semi >= 0 {
					ec.key_type, ec.key_class = parse_type_string_part(hs[:semi], cache.empty_string_name)
					ec.elem_type, ec.elem_class = parse_type_string_part(hs[semi + 1:], cache.empty_string_name)
				}
			}
		}
	}

	methods := rt.desc_methods(desc)
	cache.method_names = make([]godot.String_Name, len(methods))
	for m, i in methods {
		cache.method_names[i] = godot.new_string_name_cstring(m.name, true)
	}

	cache.export_index = make(map[uintptr]int, len(cache.exports))
	for &ex, i in cache.exports {
		cache.export_index[sn_bits(ex.name)] = i
	}
	cache.method_index = make(map[uintptr]int, len(cache.method_names))
	for mname, i in cache.method_names {
		cache.method_index[sn_bits(mname)] = i
	}

	class_caches[key] = cache
	return cache
}

// Build the Variant default for an @export (richer-authoring #3). Scalars only:
// Int/Float/Bool come from `default_num` (bool as 0/1), String from `default_str`.
// A non-defaulted export (or unsupported type) yields a NIL Variant. Package-visible so
// the script-level `_get_property_default_value` virtual (script.odin) can reuse it.
@(private)
export_default_variant :: proc "contextless" (ex: rt.Export) -> godot.Variant {
	if !ex.has_default {
		return godot.Variant{}
	}
	#partial switch ex.type {
	case .Int:
		i := godot.Int(i64(ex.default_num))
		return godot.variant_from_int(&i)
	case .Float:
		f := godot.Float(ex.default_num)
		return godot.variant_from_float(&f)
	case .Bool:
		b := ex.default_num != 0
		return godot.variant_from_bool(&b)
	case .String:
		s := godot.new_string_cstring(ex.default_str == nil ? "" : ex.default_str)
		return godot.variant_from_string(&s)
	case:
		return godot.Variant{}
	}
}

// One shared vtable for every instance (it is the same dispatch for all classes;
// the per-instance variation lives in Odin_Instance.desc).
@(private)
instance_info: gdext.ExtensionScriptInstanceInfo3
@(private)
instance_info_ready: bool

// Cached method names + the Variant->f64 constructor for the call hot path.
@(private)
process_name: godot.String_Name
@(private)
physics_process_name: godot.String_Name
@(private)
instance_names_ready: bool
@(private)
variant_to_float: gdext.TypeFromVariantConstructorProc

@(private)
ensure_instance_globals :: proc() {
	if !instance_names_ready {
		process_name = godot.new_string_name_cstring("_process", true)
		physics_process_name = godot.new_string_name_cstring("_physics_process", true)
		variant_to_float = gdext.get_variant_to_type_constructor(.Float)
		instance_names_ready = true
	}
	if !instance_info_ready {
		instance_info = gdext.ExtensionScriptInstanceInfo3 {
			set_func                       = inst_set,
			get_func                       = inst_get,
			get_property_list_func         = inst_get_property_list,
			free_property_list_func        = inst_free_property_list,
			get_class_category_func        = nil,
			property_can_revert_func       = inst_property_can_revert,
			property_get_revert_func       = inst_property_get_revert,
			get_owner_func                 = inst_get_owner,
			get_property_state_func        = inst_get_property_state,
			get_method_list_func           = inst_get_method_list,
			free_method_list_func          = inst_free_method_list,
			get_property_type_func         = inst_get_property_type,
			validate_property_func         = inst_validate_property,
			has_method_func                = inst_has_method,
			get_method_argument_count_func = inst_get_method_argument_count,
			call_func                      = inst_call,
			notification_func              = inst_notification,
			to_string_func                 = inst_to_string,
			refcount_incremented_func      = inst_refcount_incremented,
			refcount_decremented_func      = inst_refcount_decremented,
			get_script_func                = inst_get_script,
			is_placeholder_func            = inst_is_placeholder,
			set_fallback_func              = inst_set,
			get_fallback_func              = inst_get,
			get_language_func              = inst_get_language,
			free_func                      = inst_free,
		}
		instance_info_ready = true
	}
}

// ----------------------------------------------------------------------------
// Typed cross-script references (Option A). Map a Godot object to the Odin script struct
// the core allocated for it (`Odin_Instance.user`), or nil. Handed to the scripts dll at
// boot (see runtime/cross.odin + scripts_{native,web}.odin); a script then casts the
// result to its known struct type via `rt.script_of(obj, T)`.
//
// `object_get_script_instance(obj, odin_language_object)` returns the
// ExtensionScriptInstanceDataPtr we passed to `script_instance_create3` IF the object's
// script belongs to OUR language — i.e. it returns our `Odin_Instance*` for a real Odin
// instance, and nil otherwise. We additionally cross-check the pointer against the live
// instance registry, so a placeholder / stale / foreign ptr can never be dereferenced as
// an `Odin_Instance` (returns nil instead of handing back garbage).
//
// `want_class` is the class the CALLER expects (`rt.script_of(obj, T)` passes T's registered
// class name). We return `oi.user` ONLY when the live instance's class actually matches —
// otherwise nil. This is the type-safety check: every Odin script struct lives in one dll and
// shares a namespace, so without verifying the class we would hand back the WRONG struct cast
// to `^T` (e.g. a Bullet returned as a non-nil `^Enemy`), defeating the caller's nil guard and
// corrupting memory. The compare is by VALUE (`oi.class_name` is a heap copy that survives dll
// swaps; `want_class` is the scripts dll's static name cstring), and cheap — both are short
// class-name strings on a hot path called every shot/frame.
@(export)
odin_script_struct :: proc "c" (obj: gdext.ObjectPtr, want_class: cstring) -> rawptr {
	context = gdext.godot_context()
	if obj == nil || odin_language_object == nil {
		return nil
	}
	data := gdext.object_get_script_instance(obj, odin_language_object)
	if data == nil {
		return nil
	}
	oi := cast(^Odin_Instance)data
	sync.lock(&live_lock)
	defer sync.unlock(&live_lock)
	if x, ok := live_by_owner[obj]; ok && x == oi {
		// Type check: only hand back the struct if its class is the one requested.
		if want_class != nil && oi.class_name == string(want_class) {
			return oi.user
		}
	}
	return nil
}

// The ANY-class sibling of odin_script_struct, behind `rt.script_any`: the same live-
// instance lookup, but instead of VERIFYING a caller-supplied class it REPORTS the class,
// writing the instance's name (ptr + len of the core's heap copy — not NUL-terminated,
// valid while the instance lives) and returning the struct pointer. The type-safety that
// odin_script_struct gets from its compare is not lost, just relocated: the scripts dll
// resolves the reported name against ITS OWN registry to a typeid, so a class the calling
// dll never registered (a foreign module's instance) resolves to nil there, and a struct
// can never be handed out under a wrong layout.
@(export)
odin_script_struct_any :: proc "c" (obj: gdext.ObjectPtr, class_ptr: ^[^]u8, class_len: ^int) -> rawptr {
	context = gdext.godot_context()
	if obj == nil || odin_language_object == nil || class_ptr == nil || class_len == nil {
		return nil
	}
	data := gdext.object_get_script_instance(obj, odin_language_object)
	if data == nil {
		return nil
	}
	oi := cast(^Odin_Instance)data
	sync.lock(&live_lock)
	defer sync.unlock(&live_lock)
	if x, ok := live_by_owner[obj]; ok && x == oi {
		class_ptr^ = raw_data(oi.class_name)
		class_len^ = len(oi.class_name)
		return oi.user
	}
	return nil
}

// Allocator for the user script struct. Godot's `mem_alloc` guarantees only 16-byte
// alignment (and the gdext wrapper ignores the alignment argument), so an over-aligned
// class (Class_Desc.align > 16, e.g. SIMD fields) must live on the alignment-honoring
// core allocator instead. Deterministic per `align`, so inst_free/migrate_instance can
// free on the same allocator the struct was alloc'd from.
@(private)
user_struct_allocator :: proc(align: int) -> runtime.Allocator {
	if align > 16 {
		return core_allocator()
	}
	return gdext.godot_allocator()
}

// Decode ONE part of a PROPERTY_HINT_TYPE_STRING hint_string (register_class's
// encode_tag_part/encode_builtin_part): "<variant int>:" for a builtin element,
// "24/17:ClassName" for a Resource class. The leading integer (up to ':' or '/') is
// the element's Variant::Type; any text after ':' is the class name.
@(private)
parse_type_string_part :: proc(part: string, empty: godot.String_Name) -> (vt: gdext.Variant_Type, class_name: godot.String_Name) {
	class_name = empty
	n := 0
	i := 0
	for ; i < len(part) && part[i] >= '0' && part[i] <= '9'; i += 1 {
		n = n*10 + int(part[i] - '0')
	}
	vt = gdext.Variant_Type(n)
	if colon := strings.index_byte(part, ':'); colon >= 0 && colon + 1 < len(part) {
		class_name = godot.new_string_name_odin(part[colon + 1:])
	}
	return
}

// A freshly-zeroed gd.Array / gd.Dictionary field is NOT a valid engine value: both are
// one-pointer COW handles, and the engine dereferences their internals without null
// checks. SceneState::instantiate is the proven crash: for an Array property it get()s
// the CURRENT value first (to convert the stored scene value to the field's element
// type) and calls Array::is_same_typed on it — a null-internal Array SIGSEGVs there,
// so any scene-assigned Array/Dictionary export crashed on instantiate. Construct a
// real empty container in place — TYPED per the export's Type_String hint, which also
// makes that scene-load element-type conversion actually work. No-op when the field
// already holds a live value.
@(private)
seed_container_field :: proc "contextless" (user: rawptr, ex: ^Export_Cache) {
	if ex.type != .Array && ex.type != .Dictionary {return}
	fld := cast(^rawptr)(uintptr(user) + ex.offset)
	if fld^ != nil {return}
	typed := ex.hint == i64(godot.Property_Hint.Type_String)
	// gdextension_*_set_typed dereference the script pointer — pass a real NIL Variant.
	nil_script: godot.Variant
	if ex.type == .Array {
		a := godot.new_array_default()
		if typed {
			gdext.array_set_typed(
				cast(gdext.TypePtr)&a,
				ex.elem_type,
				cast(gdext.StringNamePtr)&ex.elem_class,
				cast(gdext.VariantPtr)&nil_script,
			)
		}
		(cast(^godot.Array)fld)^ = a
	} else {
		d := godot.new_dictionary_default()
		if typed {
			gdext.dictionary_set_typed(
				cast(gdext.TypePtr)&d,
				ex.key_type,
				cast(gdext.StringNamePtr)&ex.key_class,
				cast(gdext.VariantPtr)&nil_script,
				ex.elem_type,
				cast(gdext.StringNamePtr)&ex.elem_class,
				cast(gdext.VariantPtr)&nil_script,
			)
		}
		(cast(^godot.Dictionary)fld)^ = d
	}
}

// Destruct the engine value held by an @export field — for every builtin type with
// heap internals (String, StringName, NodePath, Array, Dictionary, Callable, Signal,
// all Packed_*_Arrays). That set is exactly "builtin types with a ptr destructor":
// variant_get_ptr_destructor returns nil for the POD ones, and every engine destructor
// is null-safe, so a zeroed field is a harmless no-op. `.Object` is EXCLUDED — it's a
// raw handle whose Resource refcounting is handled explicitly (script_hold_ref/
// script_release_ref). Called wherever the field's storage dies (inst_free, migrate
// re-alloc) or is overwritten (inst_set / write_export_variant) — without it every
// instance leaked one COW allocation per engine-typed export for the process lifetime.
@(private)
destruct_export_field :: proc "contextless" (user: rawptr, ex: ^Export_Cache) {
	if ex.dtor == nil {return}
	ex.dtor(cast(gdext.TypePtr)rawptr(uintptr(user) + ex.offset))
}

// Apply an @export's declared `default=...` (richer-authoring #3) to its struct field.
// A defaulted field with a setter routes through the setter so validation/side-effects
// run; otherwise it is written straight to the field. No-op without a default.
@(private)
apply_export_default :: proc "contextless" (user: rawptr, ex: ^Export_Cache) {
	if !ex.has_default {return}
	dv := ex.default
	if ex.setter != nil {
		ex.setter(user, cast(gdext.VariantPtr)&dv)
	} else {
		write_export_variant(user, ex, cast(gdext.VariantPtr)&dv)
	}
}

// Build a real script instance for `owner`, binding it to `desc`. Returns the
// engine ScriptInstancePtr to hand back from `_instance_create`.
@(private)
odin_make_script_instance :: proc(script: gdext.ObjectPtr, owner: gdext.ObjectPtr, desc: rt.Class_Desc) -> gdext.ScriptInstancePtr {
	ensure_instance_globals()

	oi := new(Odin_Instance)
	oi.owner = owner
	oi.script = script
	oi.desc = desc
	oi.cache = ensure_class_cache(desc)
	oi.class_name = heap_clone(string(desc.name))
	track_live_instance(oi)

	// Hold a STRONG reference to the OdinScript for as long as this instance lives.
	// The instance stores `script` as a raw pointer; without our own ref the script
	// resource can be freed out from under us (e.g. when the PackedScene that carried
	// the script's ExtResource ref is released after `instantiate()`), leaving a
	// dangling `oi.script`. The engine then crashes the moment it dereferences the
	// script via `script_instance->get_script()` — e.g. inside `Object::connect` /
	// `Object::emit_signalp` for a script-declared signal. This mirrors godot-cpp,
	// whose ScriptInstance keeps the script alive through a `Ref<Script>` member.
	script_hold_ref(script)

	// Allocate + zero the script's own struct; write the owner Object* at offset 0.
	// gdext's godot allocator zeroes on `.Alloc` (see gdext/context.odin) — the explicit
	// mem.zero here is belt-and-braces so a future allocator change can't reintroduce
	// garbage in non-`owner` fields.
	user, err := mem.alloc(desc.size, desc.align, user_struct_allocator(desc.align))
	if err == nil && user != nil {
		mem.zero(user, desc.size)
		(cast(^gdext.ObjectPtr)user)^ = owner

		// Seed Array/Dictionary exports with valid empty containers, then apply
		// `@export default=...` values (richer-authoring #3) — both BEFORE _ready.
		for &ex in oi.cache.exports {
			seed_container_field(user, &ex)
			apply_export_default(user, &ex)
		}
	}
	oi.user = user

	// Enable the engine callbacks this class actually handles. NB: we resolve these
	// binds LAZILY here (at .Scene/instance-create time) rather than via the generated
	// `godot.node_set_process`. The core's `godot.init()` ran at the extension entry
	// point — too early for Node method binds — so those generated pointers are null.
	// (The scripts dll dodges this by booting at .Scene; the core resolves on demand.)
	if desc.lifecycle.process != nil {
		node_enable_process(owner, true)
	}
	if desc.lifecycle.physics_process != nil {
		node_enable_physics_process(owner, true)
	}

	return gdext.script_instance_create3(&instance_info, cast(gdext.ExtensionScriptInstanceDataPtr)oi)
}

// Lazily-resolved RefCounted::reference / unreference binds (both hash 2240911060 in
// 4.6.2: no args, returns bool). We use them to keep the script resource alive for the
// instance's lifetime — exactly what a `Ref<Script>` would do in godot-cpp.
@(private)
ref_bind: gdext.MethodBindPtr
@(private)
unref_bind: gdext.MethodBindPtr

@(private)
script_hold_ref :: proc "contextless" (obj: gdext.ObjectPtr) {
	if obj == nil {return}
	if ref_bind == nil {
		cn := godot.new_string_name_cstring("RefCounted", true)
		mn := godot.new_string_name_cstring("reference", true)
		ref_bind = gdext.classdb_get_method_bind(&cn, &mn, 2240911060)
	}
	if ref_bind == nil {return}
	result: bool
	gdext.object_method_bind_ptrcall(ref_bind, obj, nil, cast(gdext.TypePtr)&result)
}

// Release the reference taken by script_hold_ref. `unreference` returns true when the
// refcount reached zero, in which case WE are responsible for destroying the object
// (this is precisely what `Ref<T>::unref()` does in the engine).
@(private)
script_release_ref :: proc "contextless" (obj: gdext.ObjectPtr) {
	if obj == nil {return}
	if unref_bind == nil {
		cn := godot.new_string_name_cstring("RefCounted", true)
		mn := godot.new_string_name_cstring("unreference", true)
		unref_bind = gdext.classdb_get_method_bind(&cn, &mn, 2240911060)
	}
	if unref_bind == nil {return}
	result: bool
	gdext.object_method_bind_ptrcall(unref_bind, obj, nil, cast(gdext.TypePtr)&result)
	if result {
		gdext.object_destroy(obj)
	}
}

// Lazily-resolved Node::set_process / set_physics_process binds (hash 2586408642 for
// both in 4.6.2). Resolved on first use, when classdb method binds are ready.
@(private)
set_process_bind: gdext.MethodBindPtr
@(private)
set_physics_process_bind: gdext.MethodBindPtr

@(private)
node_enable_process :: proc(owner: gdext.ObjectPtr, enable: bool) {
	if set_process_bind == nil {
		cn := godot.new_string_name_cstring("Node", true)
		mn := godot.new_string_name_cstring("set_process", true)
		set_process_bind = gdext.classdb_get_method_bind(&cn, &mn, 2586408642)
	}
	if set_process_bind == nil {return}
	enable := enable
	args := [1]gdext.TypePtr{&enable}
	gdext.object_method_bind_ptrcall(set_process_bind, owner, &args[0], nil)
}

@(private)
node_enable_physics_process :: proc(owner: gdext.ObjectPtr, enable: bool) {
	if set_physics_process_bind == nil {
		cn := godot.new_string_name_cstring("Node", true)
		mn := godot.new_string_name_cstring("set_physics_process", true)
		set_physics_process_bind = gdext.classdb_get_method_bind(&cn, &mn, 2586408642)
	}
	if set_physics_process_bind == nil {return}
	enable := enable
	args := [1]gdext.TypePtr{&enable}
	gdext.object_method_bind_ptrcall(set_physics_process_bind, owner, &args[0], nil)
}

// Which onready entries a resolve pass touches. Node handles and SCRIPT refs (a
// `^<script struct>` field — get_node + the class-checked struct resolver) diverge on
// hot reload: a migrated instance can re-resolve its node handles immediately, but a
// script ref points into ANOTHER instance's struct, which the rebind loop may re-alloc
// AFTER this instance resolved — so script refs get their own pass once every
// instance is rebound (rebind_all_instances).
@(private)
Onready_Pass :: enum {
	All,
	Nodes_Only,
	Scripts_Only,
}

// Resolve `@onready`-style refs (richer-authoring #1): write get_node(owner, path) —
// or, for a `^<script struct>` field, that node's Odin script struct — into each tagged
// field. Runs at NOTIFICATION_READY, and again after a hot-reload rebind (see
// Onready_Pass for the split).
@(private)
resolve_onready_refs :: proc "contextless" (oi: ^Odin_Instance, pass := Onready_Pass.All) {
	for o in rt.desc_onready(oi.desc) {
		if o.path == nil {
			// Neutralized at boot: a `^T` whose T is no registered script class
			// (fixup_onready_script_targets recorded the error; never write into it).
			continue
		}
		is_script := o.script_class != nil
		if (pass == .Nodes_Only && is_script) || (pass == .Scripts_Only && !is_script) {
			continue
		}
		if o.count == 0 {
			resolve_onready_slot(oi, o, o.path, rawptr(uintptr(oi.user) + o.offset))
			continue
		}
		// ARRAY form (`cards: [9]gd.Button `gd:"onready=Shop/Card%d"``): substitute
		// 0-based indices into the walk-validated `%d` template; elements are
		// pointer-sized, contiguous from offset. The ctprintf path is temp-arena
		// memory, consumed by get_node inside the call. scan_onready_template (not a
		// naive index) finds the substitution point: a scene-unique segment may itself
		// start with 'd' (`%dock/Card%d`) and must pass through to get_node intact.
		context = gdext.godot_context()
		tmpl := string(o.path)
		di, _, _ := rt.scan_onready_template(tmpl)
		if di < 0 {
			// Unreachable via the walk (it refuses template-less array paths); guards
			// hand-authored descs from substituting into a unique-name marker.
			godot.error_str(fmt.tprintf("%s.%s: onready array path %q has no `%%d` template — nothing resolved", oi.class_name, string(o.field), tmpl))
			continue
		}
		for i in 0 ..< int(o.count) {
			ip := fmt.ctprintf("%s%d%s", tmpl[:di], i, tmpl[di + 2:])
			resolve_onready_slot(oi, o, ip, rawptr(uintptr(oi.user) + o.offset + uintptr(i) * size_of(rawptr)))
		}
	}
}

// Cap for the indexed `@(gd_connect="…%d:sig")` probe: generous for button banks,
// small enough that a pathological scene can't stall READY.
INDEXED_CONNECT_MAX :: 64

// Wire one INDEXED connection declaration: substitute 0-based indices into the `%d`
// template, probing SILENTLY (get_node_or_null — a missing index is the loop's normal
// terminator, not an error) and connecting each match with its index bound as the
// handler's trailing arg. Zero matches is LOUD: the declaration wired nothing, which
// otherwise reads as "the handler never fires" with no hint why.
@(private)
wire_indexed_connection :: proc "contextless" (oi: ^Odin_Instance, c: rt.Connection) {
	context = gdext.godot_context()
	tmpl := string(c.path)
	di, _, _ := rt.scan_onready_template(tmpl)
	if di < 0 {
		// Unreachable via scriptgen (indexed is only set when a template exists);
		// guards hand-authored descs from substituting into a unique-name marker.
		godot.error_str(fmt.tprintf("%s.%s: indexed @(gd_connect) path %q has no `%%d` template — nothing wired", oi.class_name, string(c.method), tmpl))
		return
	}
	wired := 0
	for i in 0 ..< INDEXED_CONNECT_MAX {
		ip := fmt.ctprintf("%s%d%s", tmpl[:di], i, tmpl[di + 2:])
		np := godot.new_node_path_cstring(ip)
		node := godot.node_get_node_or_null(cast(godot.Node)oi.owner, np)
		godot.free_node_path(np)
		if node == nil {
			break
		}
		godot.connect_to_bound(cast(godot.Object)node, c.signal, cast(godot.Object)oi.owner, c.method, i64(i))
		wired += 1
	}
	if wired == 0 {
		godot.error_str(
			fmt.tprintf(
				"%s.%s: @(gd_connect=\"%s:%s\") matched no node at index 0 — nothing wired",
				oi.class_name,
				string(c.method),
				tmpl,
				string(c.signal),
			),
		)
	}
}

// Resolve ONE onready slot: get_node, then either the handle write or the class-checked
// script-struct resolve (rt.script_of semantics). Nil-safe on a missing node (get_node
// already printed the engine's path error); a node WITHOUT the wanted script is LOUD —
// the path resolved, so a silently-nil typed ref would read as "onready didn't run",
// not "wrong script on the node".
@(private)
resolve_onready_slot :: proc "contextless" (oi: ^Odin_Instance, o: rt.Onready, path: cstring, slot: rawptr) {
	node := godot.get_node(cast(godot.Object)oi.owner, path)
	if o.script_class == nil {
		(cast(^gdext.ObjectPtr)slot)^ = cast(gdext.ObjectPtr)node
		return
	}
	p := odin_script_struct(cast(gdext.ObjectPtr)node, o.script_class)
	(cast(^rawptr)slot)^ = p
	if node != nil && p == nil {
		context = gdext.godot_context()
		godot.error_str(
			fmt.tprintf(
				"%s.%s: onready script ref %q found the node, but it carries no %s Odin script — field left nil",
				oi.class_name,
				string(o.field),
				string(path),
				string(o.script_class),
			),
		)
	}
}

// ---- vtable: the hot path ----

@(private)
inst_notification :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, what: i32, reversed: bool) {
	oi := cast(^Odin_Instance)instance
	if oi == nil || oi.user == nil {
		return
	}
	switch int(what) {
	case NOTIFICATION_READY:
		// `//gd:group` memberships first of all: group-based lookups running from ANY
		// sibling's onready/connections/ready (rt.first_script_in_group and friends)
		// must already see this node grouped. The names are static cstrings from the
		// generated table (dll-lifetime), so the static intern in add_to_group is right.
		for g in rt.desc_groups(oi.desc) {
			godot.add_to_group(cast(godot.Object)oi.owner, g)
		}
		// Resolve `@onready`-style node refs (richer-authoring #1) FIRST, so the user's
		// _ready (and the gd_connect wiring below) sees fully resolved, non-null references.
		resolve_onready_refs(oi)
		// Wire `@(gd_connect="signal")` declarations: connect owner.signal -> owner.method
		// before the user's ready runs, so the connections are live for the rest of _ready.
		// The path-qualified form (`"Path/To/Node:signal"`) resolves the EMITTER like an
		// `onready=` ref first — children ready before parents, so a child emitter's script
		// (and its declared signals) exists by now.
		for c in rt.desc_connections(oi.desc) {
			if c.path == nil {
				godot.connect(cast(godot.Object)oi.owner, c.signal, c.method)
				continue
			}
			if c.indexed {
				wire_indexed_connection(oi, c)
				continue
			}
			emitter := godot.get_node(cast(godot.Object)oi.owner, c.path)
			if emitter == nil {
				// get_node already printed the engine's path error; name the DECLARATION
				// too, or the red line points at a path with no hint of which class/method
				// asked for it.
				context = gdext.godot_context()
				godot.error_str(
					fmt.tprintf(
						"%s.%s: @(gd_connect=\"%s:%s\") found no node at %q — connection skipped",
						oi.class_name,
						string(c.method),
						string(c.path),
						string(c.signal),
						string(c.path),
					),
				)
				continue
			}
			godot.connect_to(cast(godot.Object)emitter, c.signal, cast(godot.Object)oi.owner, c.method)
		}
		if oi.desc.lifecycle.ready != nil {
			oi.desc.lifecycle.ready(oi.user)
		}
	case NOTIFICATION_ENTER_TREE:
		if oi.desc.lifecycle.enter_tree != nil {
			oi.desc.lifecycle.enter_tree(oi.user)
		}
	case NOTIFICATION_EXIT_TREE:
		if oi.desc.lifecycle.exit_tree != nil {
			oi.desc.lifecycle.exit_tree(oi.user)
		}
	}
}

@(private)
inst_call :: proc "c" (
	self: gdext.ExtensionScriptInstanceDataPtr,
	method: gdext.StringNamePtr,
	args: [^]gdext.VariantPtr,
	argument_count: i64,
	ret: gdext.VariantPtr,
	error: ^gdext.CallError,
) {
	oi := cast(^Odin_Instance)self
	if oi == nil || oi.user == nil {
		if error != nil {error.error = .Invalid_Method}
		return
	}

	name := (cast(^godot.String_Name)method)^

	// Custom methods first: GDScript `obj.add(2, 3)` arrives here as a Variant call.
	// We forward args/ret straight to the class's trampoline (which unpacks/marshals).
	if oi.cache != nil {
		if i, found := oi.cache.method_index[sn_bits(name)]; found {
			// Arity guard: the trampoline reads exactly arg_types_count Variants from
			// `args`, so a short call would read past the array. Odin methods are never
			// vararg, so extra args are an error too. `expected` carries the declared
			// arity, `argument` the passed count (what Godot's call-error text reads).
			want := int(oi.desc.methods[i].arg_types_count)
			if int(argument_count) != want {
				if error != nil {
					error.error = int(argument_count) < want ? .Too_Few_Arguments : .Too_Many_Arguments
					error.argument = i32(argument_count)
					error.expected = i32(want)
				}
				return
			}
			oi.desc.methods[i].trampoline(oi.user, args, argument_count, ret)
			if error != nil {error.error = .Ok}
			return
		}
	}

	if name == process_name && oi.desc.lifecycle.process != nil {
		delta: f64
		if argument_count >= 1 && variant_to_float != nil {
			variant_to_float(&delta, args[0])
		}
		oi.desc.lifecycle.process(oi.user, delta)
		if error != nil {error.error = .Ok}
		return
	}

	if name == physics_process_name && oi.desc.lifecycle.physics_process != nil {
		delta: f64
		if argument_count >= 1 && variant_to_float != nil {
			variant_to_float(&delta, args[0])
		}
		oi.desc.lifecycle.physics_process(oi.user, delta)
		if error != nil {error.error = .Ok}
		return
	}

	// Not ours — tell the engine so its built-in dispatch continues.
	if error != nil {error.error = .Invalid_Method}
}

@(private)
inst_has_method :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, name: gdext.StringNamePtr) -> bool {
	oi := cast(^Odin_Instance)instance
	if oi == nil {
		return false
	}
	n := (cast(^godot.String_Name)name)^
	if n == process_name {return oi.desc.lifecycle.process != nil}
	if n == physics_process_name {return oi.desc.lifecycle.physics_process != nil}
	if oi.cache != nil {
		if _, found := oi.cache.method_index[sn_bits(n)]; found {return true}
	}
	return false
}

@(private)
inst_get_owner :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr) -> gdext.ObjectPtr {
	oi := cast(^Odin_Instance)instance
	return oi != nil ? oi.owner : nil
}

@(private)
inst_get_script :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr) -> gdext.ObjectPtr {
	oi := cast(^Odin_Instance)instance
	return oi != nil ? oi.script : nil
}

@(private)
inst_get_language :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr) -> gdext.ExtensionScriptLanguagePtr {
	return cast(gdext.ExtensionScriptLanguagePtr)odin_language_object
}

@(private)
inst_free :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr) {
	context = gdext.godot_context()
	oi := cast(^Odin_Instance)instance
	if oi == nil {
		return
	}
	untrack_live_instance(oi)
	script_release_ref(oi.script) // release the ref taken in odin_make_script_instance
	// Release any resource references retained by RESOURCE-typed @export fields (inst_set),
	// and destruct every engine-value export field with heap internals (String, packed
	// arrays, Array, Dictionary, ...) — otherwise each instance leaks those allocations
	// (and everything they hold, e.g. Resources inside an Array) for the process lifetime.
	if oi.cache != nil && oi.user != nil {
		for &ex in oi.cache.exports {
			if ex.type == .Object && ex.hint == i64(godot.Property_Hint.Resource_Type) {
				fld := rawptr(uintptr(oi.user) + ex.offset)
				script_release_ref((cast(^gdext.ObjectPtr)fld)^)
			}
			destruct_export_field(oi.user, &ex)
		}
	}
	heap_delete_string(oi.class_name)
	if oi.user != nil {
		mem.free(oi.user, user_struct_allocator(oi.desc.align))
	}
	free(oi)
}

// ---- vtable: Phase-3 @export property surfaces ----

// PROPERTY_USAGE_STORAGE (2) | PROPERTY_USAGE_EDITOR (4) == DEFAULT — serializes + shows.
PROPERTY_USAGE_DEFAULT :: 6
// Group/subgroup header markers (richer-authoring #2). A NIL-typed property entry whose
// usage is GROUP/SUBGROUP makes the Inspector render a collapsible header; following
// properties fall under it until the next marker. (Matches godot.Property_Usage_Flags.)
PROPERTY_USAGE_GROUP :: 64
PROPERTY_USAGE_SUBGROUP :: 256

@(private)
inst_find_export :: proc "contextless" (oi: ^Odin_Instance, name: gdext.StringNamePtr) -> ^Export_Cache {
	if oi == nil || oi.cache == nil {
		return nil
	}
	n := (cast(^godot.String_Name)name)^
	if i, found := oi.cache.export_index[sn_bits(n)]; found {
		return &oi.cache.exports[i]
	}
	return nil
}

// Write a Variant into the struct field at `oi.user + ex.offset`, narrowing the
// Variant's native width (Int=i64, Float=f64) to the field's real width as needed.
@(private)
inst_set :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, name: gdext.StringNamePtr, value: gdext.VariantPtr) -> bool {
	oi := cast(^Odin_Instance)instance
	if oi == nil || oi.user == nil {
		return false
	}
	ex := inst_find_export(oi, name)
	if ex == nil {
		return false
	}
	// Getter/setter routing (richer-authoring #4): a setter validates/transforms the write.
	if ex.setter != nil {
		// A RESOURCE-typed export needs the same hold/release bookkeeping as the plain
		// field path below even when the write routes through a setter — inst_free
		// unconditionally releases every Resource_Type field's final value, so a
		// setter-written resource that was never held would underflow its refcount.
		if ex.type == .Object && ex.hint == i64(godot.Property_Hint.Resource_Type) {
			fld := cast(^gdext.ObjectPtr)(uintptr(oi.user) + ex.offset)
			old := fld^
			ex.setter(oi.user, value)
			newp := fld^
			if newp != old {
				script_hold_ref(newp)
				script_release_ref(old)
			}
		} else {
			ex.setter(oi.user, value)
		}
		return true
	}
	if ex.to_type == nil {
		return false
	}
	dst := rawptr(uintptr(oi.user) + ex.offset)
	#partial switch ex.type {
	case .Float:
		tmp: f64
		ex.to_type(&tmp, value)
		if ex.size == 4 {
			(cast(^f32)dst)^ = f32(tmp)
		} else {
			(cast(^f64)dst)^ = tmp
		}
	case .Int:
		tmp: i64
		ex.to_type(&tmp, value)
		switch ex.size {
		case 1:
			(cast(^i8)dst)^ = i8(tmp)
		case 2:
			(cast(^i16)dst)^ = i16(tmp)
		case 4:
			(cast(^i32)dst)^ = i32(tmp)
		case:
			(cast(^i64)dst)^ = tmp
		}
	case:
		// Engine-native types (Vector2, String, Object, ...) match the field width.
		// Drop the old COW/ref'd value first (String/Array/packed/... — no-op for POD
		// and .Object): to_type CONSTRUCTS over the bytes, so overwriting leaked the
		// previous allocation. Safe for self-assignment — the incoming Variant holds
		// its own reference to the value.
		destruct_export_field(oi.user, ex)
		// A RESOURCE-typed Object export (hint Resource_Type) holds a RefCounted; we must
		// take a reference so the assigned resource stays alive for as long as this instance
		// references it (a `Ref<Resource>` would do this in godot-cpp). Without it, a resource
		// assigned from a scene/.tres is freed once the loader's transient ref drops, leaving
		// the field dangling. We release the previously-held resource (if any) on overwrite,
		// and release the final one in inst_free.
		if ex.type == .Object && ex.hint == i64(godot.Property_Hint.Resource_Type) {
			old := (cast(^gdext.ObjectPtr)dst)^
			ex.to_type(dst, value)
			newp := (cast(^gdext.ObjectPtr)dst)^
			if newp != old {
				script_hold_ref(newp)
				script_release_ref(old)
			}
		} else {
			ex.to_type(dst, value)
		}
	}
	return true
}

@(private)
inst_get :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, name: gdext.StringNamePtr, ret: gdext.VariantPtr) -> bool {
	oi := cast(^Odin_Instance)instance
	if oi == nil || oi.user == nil {
		return false
	}
	ex := inst_find_export(oi, name)
	if ex == nil {
		return false
	}
	// Getter/setter routing (richer-authoring #4): a getter computes the reported value.
	if ex.getter != nil {
		ex.getter(oi.user, ret)
		return true
	}
	if ex.from_type == nil {
		return false
	}
	// Heal a zeroed Array/Dictionary field (e.g. script code assigned the Odin zero
	// value) — marshalling a null-internal container into a Variant crashes the engine.
	seed_container_field(oi.user, ex)
	src := rawptr(uintptr(oi.user) + ex.offset)
	#partial switch ex.type {
	case .Float:
		tmp: f64
		if ex.size == 4 {
			tmp = f64((cast(^f32)src)^)
		} else {
			tmp = (cast(^f64)src)^
		}
		ex.from_type(ret, &tmp)
	case .Int:
		tmp: i64
		switch ex.size {
		case 1:
			tmp = i64((cast(^i8)src)^)
		case 2:
			tmp = i64((cast(^i16)src)^)
		case 4:
			tmp = i64((cast(^i32)src)^)
		case:
			tmp = (cast(^i64)src)^
		}
		ex.from_type(ret, &tmp)
	case:
		ex.from_type(ret, src)
	}
	return true
}

@(private)
inst_get_property_list :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, count: ^u32) -> [^]gdext.PropertyInfo {
	context = gdext.godot_context()
	oi := cast(^Odin_Instance)instance
	if oi == nil || oi.cache == nil || len(oi.cache.exports) == 0 {
		if count != nil {count^ = 0}
		return nil
	}
	n := len(oi.cache.exports)
	// Group/subgroup markers are interleaved before the property that declares them, so the
	// final count may exceed `n`. Build into a dynamic list, then hand back its raw data.
	list := make([dynamic]gdext.PropertyInfo, 0, n)
	for i in 0 ..< n {
		ex := &oi.cache.exports[i]
		if ex.has_group {
			append(&list, gdext.PropertyInfo {
				type        = .Nil,
				name        = cast(gdext.StringNamePtr)&ex.group,
				class_name  = cast(gdext.StringNamePtr)&oi.cache.empty_string_name,
				hint        = 0,
				hint_string = cast(gdext.StringPtr)&oi.cache.empty_string,
				usage       = PROPERTY_USAGE_GROUP,
			})
		}
		if ex.has_subgroup {
			append(&list, gdext.PropertyInfo {
				type        = .Nil,
				name        = cast(gdext.StringNamePtr)&ex.subgroup,
				class_name  = cast(gdext.StringNamePtr)&oi.cache.empty_string_name,
				hint        = 0,
				hint_string = cast(gdext.StringPtr)&oi.cache.empty_string,
				usage       = PROPERTY_USAGE_SUBGROUP,
			})
		}
		append(&list, gdext.PropertyInfo {
			type        = ex.type,
			name        = cast(gdext.StringNamePtr)&ex.name,
			class_name  = cast(gdext.StringNamePtr)&oi.cache.empty_string_name,
			hint        = u32(ex.hint),
			hint_string = cast(gdext.StringPtr)&ex.hint_string,
			usage       = PROPERTY_USAGE_DEFAULT,
		})
	}
	if count != nil {count^ = u32(len(list))}
	return raw_data(list)
}

@(private)
inst_free_property_list :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, list: ^gdext.PropertyInfo, count: u32) {
	context = gdext.godot_context()
	if list != nil {
		// Reconstruct the slice we allocated in inst_get_property_list and free it.
		// INVARIANT: `count` may be less than the dynamic array's grown CAPACITY, so this
		// delete passes a smaller size than was allocated — valid only because the godot
		// allocator's `.Free` ignores size (plain `mem_free`). A size-checking allocator
		// here would need inst_get_property_list to shrink-to-fit (or pass the capacity).
		s := transmute([]gdext.PropertyInfo)runtime.Raw_Slice{data = list, len = int(count)}
		delete(s)
	}
}

@(private)
inst_get_property_state :: proc "c" (
	instance: gdext.ExtensionScriptInstanceDataPtr,
	add_func: gdext.ExtensionScriptInstancePropertyStateAdd,
	user_data: rawptr,
) {
}

@(private)
inst_get_method_list :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, count: ^u32) -> [^]gdext.MethodInfo {
	if count != nil {count^ = 0}
	return nil
}

@(private)
inst_free_method_list :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, list: ^gdext.MethodInfo, count: u32) {
}

@(private)
inst_get_property_type :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, name: gdext.StringNamePtr, is_valid: ^bool) -> gdext.Variant_Type {
	oi := cast(^Odin_Instance)instance
	ex := inst_find_export(oi, name)
	if ex != nil {
		if is_valid != nil {is_valid^ = true}
		return ex.type
	}
	if is_valid != nil {is_valid^ = false}
	return .Nil
}

@(private)
inst_validate_property :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, property: ^gdext.PropertyInfo) -> bool {
	return false
}

@(private)
inst_get_method_argument_count :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, name: gdext.StringNamePtr, is_valid: ^bool) -> i64 {
	oi := cast(^Odin_Instance)instance
	if oi != nil && oi.cache != nil {
		n := (cast(^godot.String_Name)name)^
		if i, found := oi.cache.method_index[sn_bits(n)]; found {
			if is_valid != nil {is_valid^ = true}
			return i64(oi.desc.methods[i].arg_types_count)
		}
	}
	if is_valid != nil {is_valid^ = false}
	return 0
}

@(private)
inst_property_can_revert :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, name: gdext.StringNamePtr) -> bool {
	return false
}

@(private)
inst_property_get_revert :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, name: gdext.StringNamePtr, ret: gdext.VariantPtr) -> bool {
	return false
}

@(private)
inst_to_string :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, is_valid: ^bool, out: gdext.StringPtr) {
	if is_valid != nil {is_valid^ = false}
}

@(private)
inst_refcount_incremented :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr) {
}

@(private)
inst_refcount_decremented :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr) -> bool {
	return false
}

@(private)
inst_is_placeholder :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr) -> bool {
	return false
}

// ----------------------------------------------------------------------------
// Phase 4 — re-binding live instances after a scripts-dll swap.
//
// `rebind_all_instances` is called by `odin_scripts_reload` (core/scripts.odin)
// AFTER the new dll is booted, its manifest pulled into `scripts_classes`, and the
// per-class caches invalidated. For each live instance:
//   - same struct layout (the common edit-a-proc-body case): keep the existing
//     struct bytes in place and just point `desc`/`cache` at the new descriptors —
//     ALL state preserved (exports + private fields), no re-alloc.
//   - changed layout (fields added/reordered): export-preserving migration — snapshot
//     each @export to a Variant, re-alloc the struct at the new size, re-apply the
//     exports by name, re-store `owner`. Non-exported private fields reset (a
//     documented limitation; GDScript has the same reload caveat).
// ----------------------------------------------------------------------------

// `only` scopes the rebind to instances of the given class names (multi-module spike:
// a per-module swap must leave OTHER modules' instances — descs, caches, struct bytes —
// completely untouched). nil == rebind everything (the single-module behavior).
@(private)
rebind_all_instances :: proc(only: map[string]bool = nil) {
	// Snapshot the registry under the lock, rebind OUTSIDE it: the rebind path calls into
	// Godot (ensure_class_cache interning, get_node) and into script code
	// (lifecycle.reload, which may call rt.script_of -> odin_script_struct -> the same
	// non-recursive live_lock).
	sync.lock(&live_lock)
	snapshot := make([]^Odin_Instance, len(live_instances), context.temp_allocator)
	copy(snapshot, live_instances[:])
	sync.unlock(&live_lock)

	for oi in snapshot {
		if oi == nil {
			continue
		}
		if only != nil && !(oi.class_name in only) {
			continue // another module's instance — must survive the swap untouched
		}
		new_desc, ok := scripts_classes[oi.class_name]
		if !ok {
			// Class no longer provided by the new dll: leave the instance bound to its
			// old (still-mapped) desc so nothing dangles. It simply won't update.
			continue
		}
		new_cache := ensure_class_cache(new_desc)
		if layout_compatible(oi.desc, new_desc) {
			oi.desc = new_desc
			oi.cache = new_cache
		} else {
			migrate_instance(oi, new_desc, new_cache)
		}
		// Hot-reload hook: the instance is now bound to the NEW desc + (preserved or
		// migrated) state. Give the script a chance to rebuild what the swap can't fix
		// itself — chiefly raw proc pointers it cached into its own struct, which on a
		// same-layout reload survive byte-for-byte and still point at stale old code.
		// Runs with the new code (nil when the class defines no `<class>_reload`).
		if oi.desc.lifecycle.reload != nil {
			oi.desc.lifecycle.reload(oi.user)
		}
	}

	// SECOND PASS — script-onready refs (`hud: ^hud`). They point into OTHER instances'
	// structs, so no instance's refs are trustworthy until EVERY instance is rebound:
	// a changed-layout target re-allocs its struct, dangling whatever the first loop
	// (or the pre-reload world) resolved. Same-layout instances need this too — their
	// bytes survived, but the struct their pointer targets may not have. (The manual
	// `rt.script_of`-in-ready idiom has exactly this dangle and no second chance;
	// the declared form is what makes reload safe.) Reload hooks above run BEFORE
	// this pass, so they must not dereference script-onready refs.
	for oi in snapshot {
		if oi == nil || oi.desc.onready_count == 0 {
			continue
		}
		if only != nil && !(oi.class_name in only) {
			continue
		}
		has_script := false
		for o in rt.desc_onready(oi.desc) {
			if o.script_class != nil {
				has_script = true
				break
			}
		}
		if has_script && bool(godot.node_is_inside_tree(cast(godot.Node)oi.owner)) {
			resolve_onready_refs(oi, .Scripts_Only)
		}
	}
}

// Two descriptors share a struct layout iff size/align match AND every @export keeps
// the same name/type/offset/size. (Reads `a`'s exports from the OLD dll image, which
// stays mapped across the swap.) A reasonable proxy for "an edit that only changed
// proc bodies, not the struct".
@(private)
layout_compatible :: proc(a, b: rt.Class_Desc) -> bool {
	if a.size != b.size || a.align != b.align {
		return false
	}
	a_exports := rt.desc_exports(a)
	b_exports := rt.desc_exports(b)
	if len(a_exports) != len(b_exports) {
		return false
	}
	for i in 0 ..< len(a_exports) {
		ae := a_exports[i]
		be := b_exports[i]
		if ae.offset != be.offset || ae.size != be.size || ae.type != be.type {
			return false
		}
		if string(ae.name) != string(be.name) {
			return false
		}
	}
	return true
}

// Read the script field backing `ex` into a fresh Variant (narrowing handled like
// inst_get). Scalar reads do not allocate.
@(private)
read_export_variant :: proc "contextless" (user: rawptr, ex: ^Export_Cache) -> godot.Variant {
	v: godot.Variant
	seed_container_field(user, ex) // never marshal a zeroed (null-internal) container
	src := rawptr(uintptr(user) + ex.offset)
	#partial switch ex.type {
	case .Float:
		tmp: f64
		if ex.size == 4 {
			tmp = f64((cast(^f32)src)^)
		} else {
			tmp = (cast(^f64)src)^
		}
		ex.from_type(cast(gdext.VariantPtr)&v, &tmp)
	case .Int:
		tmp: i64
		switch ex.size {
		case 1:
			tmp = i64((cast(^i8)src)^)
		case 2:
			tmp = i64((cast(^i16)src)^)
		case 4:
			tmp = i64((cast(^i32)src)^)
		case:
			tmp = (cast(^i64)src)^
		}
		ex.from_type(cast(gdext.VariantPtr)&v, &tmp)
	case:
		ex.from_type(cast(gdext.VariantPtr)&v, src)
	}
	return v
}

// Write a Variant into the script field backing `ex` (narrowing handled like inst_set).
@(private)
write_export_variant :: proc "contextless" (user: rawptr, ex: ^Export_Cache, value: gdext.VariantPtr) {
	dst := rawptr(uintptr(user) + ex.offset)
	#partial switch ex.type {
	case .Float:
		tmp: f64
		ex.to_type(&tmp, value)
		if ex.size == 4 {
			(cast(^f32)dst)^ = f32(tmp)
		} else {
			(cast(^f64)dst)^ = tmp
		}
	case .Int:
		tmp: i64
		ex.to_type(&tmp, value)
		switch ex.size {
		case 1:
			(cast(^i8)dst)^ = i8(tmp)
		case 2:
			(cast(^i16)dst)^ = i16(tmp)
		case 4:
			(cast(^i32)dst)^ = i32(tmp)
		case:
			(cast(^i64)dst)^ = tmp
		}
	case:
		// Same overwrite rule as inst_set: drop the old COW/ref'd value before
		// constructing the new one over its bytes (no-op for POD and .Object).
		destruct_export_field(user, ex)
		ex.to_type(dst, value)
	}
}

// Changed-layout fallback: preserve @export values across a re-alloc to the new size.
@(private)
migrate_instance :: proc(oi: ^Odin_Instance, new_desc: rt.Class_Desc, new_cache: ^Class_Cache) {
	Saved :: struct {
		name: godot.String_Name,
		v:    godot.Variant,
	}
	saved := make([dynamic]Saved, 0, len(oi.cache.exports), core_allocator())
	defer delete(saved)
	for &ex in oi.cache.exports {
		append(&saved, Saved{ex.name, read_export_variant(oi.user, &ex)})
	}

	// Free/realloc the script struct on the allocator odin_make_script_instance used
	// (user_struct_allocator — the OLD desc picks the free side, the NEW one the alloc).
	// Engine-value fields drop their own ref first (the snapshot Variants hold another).
	for &ex in oi.cache.exports {
		destruct_export_field(oi.user, &ex)
	}
	mem.free(oi.user, user_struct_allocator(oi.desc.align))
	user, _ := mem.alloc(new_desc.size, new_desc.align, user_struct_allocator(new_desc.align))
	if user != nil {
		(cast(^gdext.ObjectPtr)user)^ = oi.owner
	}
	oi.user = user
	oi.desc = new_desc
	oi.cache = new_cache

	for &nex in oi.cache.exports {
		restored := false
		for s in saved {
			if s.name == nex.name {
				sv := s.v
				write_export_variant(oi.user, &nex, cast(gdext.VariantPtr)&sv)
				restored = true
				break
			}
		}
		// An export NEW in this layout (absent from the snapshot) starts from a seeded
		// container + its declared default, exactly like a fresh instance — not from
		// zeroed memory.
		if !restored {
			seed_container_field(oi.user, &nex)
			apply_export_default(oi.user, &nex)
		}
	}

	// The re-alloc zeroed the `@onready` fields; resolve them again so the migrated
	// instance doesn't run the new code against nil node refs. Guarded: get_node is only
	// meaningful once the owner is in the tree (pre-READY instances resolve at READY).
	// NODES ONLY: script refs point into other instances' structs, which the rebind
	// loop may still re-alloc after this one — they re-resolve in rebind_all_instances'
	// second pass, once every instance is rebound.
	if oi.desc.onready_count > 0 && bool(godot.node_is_inside_tree(cast(godot.Node)oi.owner)) {
		resolve_onready_refs(oi, .Nodes_Only)
	}

	// The snapshot Variants own refs (String/Object/...); destroy them or every
	// changed-layout reload leaks one Variant per export.
	for &s in saved {
		gdext.variant_destroy(cast(gdext.VariantPtr)&s.v)
	}
}
