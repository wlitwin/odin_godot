package core

import "godot:gdext"
import "godot:godot"
import rt "godot:runtime"

import "base:runtime"
import "core:mem"
import "core:strings"

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

@(private)
track_live_instance :: proc(oi: ^Odin_Instance) {
	context.allocator = core_allocator()
	append(&live_instances, oi)
}

@(private)
untrack_live_instance :: proc(oi: ^Odin_Instance) {
	context.allocator = core_allocator()
	for x, i in live_instances {
		if x == oi {
			unordered_remove(&live_instances, i)
			return
		}
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
	to_type:     gdext.TypeFromVariantConstructorProc, // Variant -> field
	from_type:   gdext.VariantFromTypeConstructorProc, // field   -> Variant
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
	empty_string:      godot.String,
	empty_string_name: godot.String_Name,
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

	cache.exports = make([]Export_Cache, len(desc.exports))
	for ex, i in desc.exports {
		cache.exports[i] = Export_Cache {
			name        = godot.new_string_name_cstring(ex.name, true),
			type        = ex.type,
			offset      = ex.offset,
			size        = ex.size,
			hint        = ex.hint,
			hint_string = godot.new_string_cstring(ex.hint_string == nil ? "" : ex.hint_string),
			to_type     = gdext.get_variant_to_type_constructor(ex.type),
			from_type   = gdext.get_variant_from_type_constructor(ex.type),
			has_group    = ex.group != nil,
			group        = godot.new_string_name_cstring(ex.group == nil ? "" : ex.group, true),
			has_subgroup = ex.subgroup != nil,
			subgroup     = godot.new_string_name_cstring(ex.subgroup == nil ? "" : ex.subgroup, true),
			has_default  = ex.has_default,
			default      = export_default_variant(ex),
			getter       = ex.getter,
			setter       = ex.setter,
		}
	}

	cache.method_names = make([]godot.String_Name, len(desc.methods))
	for m, i in desc.methods {
		cache.method_names[i] = godot.new_string_name_cstring(m.name, true)
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
	for x in live_instances {
		if x == oi {
			// Type check: only hand back the struct if its class is the one requested.
			if want_class != nil && oi.class_name == string(want_class) {
				return oi.user
			}
			return nil
		}
	}
	return nil
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
	// The Godot allocator's `.Alloc` does not actually zero (it just wraps `mem_alloc`),
	// so zero explicitly — otherwise non-`owner` fields would start as garbage on web.
	user, err := mem.alloc(desc.size, desc.align)
	if err == nil && user != nil {
		mem.zero(user, desc.size)
		(cast(^gdext.ObjectPtr)user)^ = owner

		// Apply `@export default=...` values (richer-authoring #3) onto the freshly-zeroed
		// struct, BEFORE _ready. A defaulted field with a setter routes through the setter so
		// validation/side-effects run; otherwise it is written straight to the field.
		for &ex in oi.cache.exports {
			if !ex.has_default {continue}
			dv := ex.default
			if ex.setter != nil {
				ex.setter(user, cast(gdext.VariantPtr)&dv)
			} else {
				write_export_variant(user, &ex, cast(gdext.VariantPtr)&dv)
			}
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

// ---- vtable: the hot path ----

@(private)
inst_notification :: proc "c" (instance: gdext.ExtensionScriptInstanceDataPtr, what: i32, reversed: bool) {
	oi := cast(^Odin_Instance)instance
	if oi == nil || oi.user == nil {
		return
	}
	switch int(what) {
	case NOTIFICATION_READY:
		// Resolve `@onready`-style node refs (richer-authoring #1) FIRST: write
		// get_node(owner, path) into each tagged field, so the user's _ready (and the
		// gd_connect wiring below) sees fully resolved, non-null references.
		for o in oi.desc.onready {
			node := godot.get_node(cast(godot.Object)oi.owner, o.path)
			(cast(^gdext.ObjectPtr)(uintptr(oi.user) + o.offset))^ = cast(gdext.ObjectPtr)node
		}
		// Wire `@(gd_connect="signal")` declarations: connect owner.signal -> owner.method
		// before the user's ready runs, so the connections are live for the rest of _ready.
		for c in oi.desc.connections {
			godot.connect(cast(godot.Object)oi.owner, c.signal, c.method)
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
		for mname, i in oi.cache.method_names {
			if name == mname {
				oi.desc.methods[i].trampoline(oi.user, args, argument_count, ret)
				if error != nil {error.error = .Ok}
				return
			}
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
		for mname in oi.cache.method_names {
			if n == mname {return true}
		}
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
	// Release any resource references retained by RESOURCE-typed @export fields (inst_set).
	if oi.cache != nil && oi.user != nil {
		for &ex in oi.cache.exports {
			if ex.type == .Object && ex.hint == i64(godot.Property_Hint.Resource_Type) {
				fld := rawptr(uintptr(oi.user) + ex.offset)
				script_release_ref((cast(^gdext.ObjectPtr)fld)^)
			}
		}
	}
	heap_delete_string(oi.class_name)
	if oi.user != nil {
		mem.free(oi.user)
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
	for &ex in oi.cache.exports {
		if n == ex.name {
			return &ex
		}
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
		ex.setter(oi.user, value)
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
		for mname, i in oi.cache.method_names {
			if n == mname {
				if is_valid != nil {is_valid^ = true}
				return i64(len(oi.desc.methods[i].arg_types))
			}
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

@(private)
rebind_all_instances :: proc() {
	for oi in live_instances {
		if oi == nil {
			continue
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
	if len(a.exports) != len(b.exports) {
		return false
	}
	for i in 0 ..< len(a.exports) {
		ae := a.exports[i]
		be := b.exports[i]
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
		ex.to_type(dst, value)
	}
}

// Changed-layout fallback: preserve @export values across a re-alloc to the new size.
@(private)
migrate_instance :: proc(oi: ^Odin_Instance, new_desc: rt.Class_Desc, new_cache: ^Class_Cache) {
	// The script struct was alloc'd on the GODOT allocator (see odin_make_script_instance,
	// which runs in godot context); free/realloc it on the SAME allocator.
	gctx := gdext.godot_context()

	Saved :: struct {
		name: godot.String_Name,
		v:    godot.Variant,
	}
	saved := make([dynamic]Saved, 0, len(oi.cache.exports), core_allocator())
	defer delete(saved)
	for &ex in oi.cache.exports {
		append(&saved, Saved{ex.name, read_export_variant(oi.user, &ex)})
	}

	mem.free(oi.user, gctx.allocator)
	user, _ := mem.alloc(new_desc.size, new_desc.align, gctx.allocator)
	if user != nil {
		(cast(^gdext.ObjectPtr)user)^ = oi.owner
	}
	oi.user = user
	oi.desc = new_desc
	oi.cache = new_cache

	for &nex in oi.cache.exports {
		for s in saved {
			if s.name == nex.name {
				sv := s.v
				write_export_variant(oi.user, &nex, cast(gdext.VariantPtr)&sv)
				break
			}
		}
	}
}
