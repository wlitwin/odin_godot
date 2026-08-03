package godot

import "core:fmt"
import "godot:gdext"

// ----------------------------------------------------------------------------
// vcall — the by-name cross-module call in ONE line. Module isolation makes the engine
// the interface between script modules (they cannot import each other's types), and the
// raw spelling of that was two lines PER ARGUMENT: a `variant_from_*` per value, then
// `object_call`, then a `variant_to_*` on the result — a 7-arg call ran 15 lines. vcall
// converts Odin arguments to Variants automatically, makes the call, and frees every
// temporary; the typed forms (`vcall_int` & co.) also unwrap + free the result.
//
//     hits := gd.vcall_int(field, "spawn_aimed", x, y, sx, sy, speed, dmg, gd.Int(1))
//     if gd.vcall_bool(gs, "is_cleared") { ... }
//     gd.vcall_void(spawner, "register_kill")
//
// Argument types accepted: integers (any width; become Int), f32/f64 (become Float),
// bool, cstring/string (become String), gd.String, gd.String_Name, node/object handles
// (gd.Node, gd.Label, … — any rawptr-alias handle), the math structs Vector2/2i/3/3i/4,
// Color and Rect2, and a prebuilt Variant (passed through UNTOUCHED — the caller keeps
// ownership). Anything else refuses the WHOLE call loudly (push_error naming the arg)
// rather than sending a half-converted argument list.
//
// `method` must be a string literal (or another program-lifetime cstring) — it is
// interned statically, like every name the connect/emit helpers take. A nil `obj` is a
// silent no-op returning the zero value: by-name targets are routinely group/path
// lookups that legitimately miss (the callers all guard, so the guard is now built in).
// ----------------------------------------------------------------------------

// The maximum vcall arity — matches object_call's own vararg buffer (minus the method).
VCALL_MAX_ARGS :: 16

@(private = "file")
Vcall_Args :: struct {
	vals:  [VCALL_MAX_ARGS]Variant,
	owned: [VCALL_MAX_ARGS]bool, // passthrough Variants stay caller-owned
	n:     int,
	ok:    bool,
}

@(private = "file")
build_vcall_args :: proc(method: cstring, args: []any) -> (out: Vcall_Args) {
	if len(args) > VCALL_MAX_ARGS {
		error_str(fmt.tprintf("vcall %q: %d arguments (max %d) — call refused", method, len(args), VCALL_MAX_ARGS))
		return
	}
	for a, i in args {
		v: Variant
		own := true
		switch t in a {
		case i64:
			x := Int(t);v = variant_from_int(&x)
		case int:
			x := Int(t);v = variant_from_int(&x)
		case i32:
			x := Int(t);v = variant_from_int(&x)
		case i16:
			x := Int(t);v = variant_from_int(&x)
		case i8:
			x := Int(t);v = variant_from_int(&x)
		case u64:
			x := Int(t);v = variant_from_int(&x)
		case u32:
			x := Int(t);v = variant_from_int(&x)
		case u16:
			x := Int(t);v = variant_from_int(&x)
		case u8:
			x := Int(t);v = variant_from_int(&x)
		case uint:
			x := Int(t);v = variant_from_int(&x)
		case f64:
			x := Float(t);v = variant_from_float(&x)
		case f32:
			x := Float(t);v = variant_from_float(&x)
		case bool:
			x := t;v = variant_from_bool(&x)
		case cstring:
			s := new_string_cstring(t)
			defer free_string(s)
			v = variant_from_string(&s)
		case string:
			s := new_string_odin(t)
			defer free_string(s)
			v = variant_from_string(&s)
		case String:
			s := t
			v = variant_from_string(&s)
		case String_Name:
			s := t
			v = variant_from_string_name(&s)
		case Object:
			// Every non-refcounted class handle (gd.Node, gd.Label, …) aliases the
			// DISTINCT Object type, so this is the arm a node handle lands in.
			o := t
			v = variant_from_object(&o)
		case rawptr:
			// A hand-spelled rawptr still converts — interop escape hatch.
			o := cast(Object)t
			v = variant_from_object(&o)
		case Vector2:
			x := t;v = variant_from_vector2(&x)
		case Vector2i:
			x := t;v = variant_from_vector2i(&x)
		case Vector3:
			x := t;v = variant_from_vector3(&x)
		case Vector3i:
			x := t;v = variant_from_vector3i(&x)
		case Vector4:
			x := t;v = variant_from_vector4(&x)
		case Color:
			x := t;v = variant_from_color(&x)
		case Rect2:
			x := t;v = variant_from_rect2(&x)
		case Variant:
			v = t
			own = false
		case:
			// Refuse the WHOLE call: a partially-converted argument list dispatched
			// anyway would be a silently-wrong call — the failure this helper exists
			// to prevent.
			error_str(fmt.tprintf("vcall %q: argument %d has unsupported type %v — call refused (see Ergonomics_Calls.odin for the accepted set)", method, i, a.id))
			for j in 0 ..< out.n {
				if out.owned[j] {variant_destroy(&out.vals[j])}
			}
			out.n = 0
			return
		}
		out.vals[i] = v
		out.owned[i] = own
		out.n = i + 1
	}
	out.ok = true
	return
}

@(private = "file")
destroy_vcall_args :: proc(a: ^Vcall_Args) {
	for i in 0 ..< a.n {
		if a.owned[i] {variant_destroy(&a.vals[i])}
	}
}

// vcall calls `method` on `obj` by name. The returned Variant is OWNED BY THE CALLER
// (variant_destroy it) — prefer the typed forms below, which unwrap and free it.
vcall :: proc(obj: Object, method: cstring, args: ..any) -> (ret: Variant) {
	if obj == nil {return}
	va := build_vcall_args(method, args)
	if !va.ok {return}
	defer destroy_vcall_args(&va)
	m := sname(method)
	return object_call(obj, m, ..va.vals[:va.n])
}

// vcall_void — call and discard the result.
vcall_void :: proc(obj: Object, method: cstring, args: ..any) {
	v := vcall(obj, method, ..args)
	variant_destroy(&v)
}

// vcall_int — call and unwrap an integer result (0 on nil obj / refused call).
vcall_int :: proc(obj: Object, method: cstring, args: ..any) -> i64 {
	v := vcall(obj, method, ..args)
	defer variant_destroy(&v)
	return i64(variant_to_int(&v))
}

// vcall_float — call and unwrap a float result.
vcall_float :: proc(obj: Object, method: cstring, args: ..any) -> f64 {
	v := vcall(obj, method, ..args)
	defer variant_destroy(&v)
	return f64(variant_to_float(&v))
}

// vcall_bool — call and unwrap a bool result.
vcall_bool :: proc(obj: Object, method: cstring, args: ..any) -> bool {
	v := vcall(obj, method, ..args)
	defer variant_destroy(&v)
	return bool(variant_to_bool(&v))
}

// vcall_str — call and unwrap a String result into an Odin string ALLOCATED from
// `allocator` (caller frees, like gd.get_string).
vcall_str :: proc(obj: Object, method: cstring, args: ..any, allocator := context.allocator) -> string {
	v := vcall(obj, method, ..args)
	defer variant_destroy(&v)
	s := variant_to_string(&v)
	defer free_string(s)
	length := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
	if length <= 0 {
		return ""
	}
	buf := make([]u8, length, allocator)
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), length)
	return string(buf)
}
