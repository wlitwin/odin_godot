package godot

import gdext "godot:gdext"

// Ergonomic helpers for dynamic (by-name) property get/set — hand-written and owned here
// (binding regeneration only rewrites *.gen.odin).
//
// These wrap Object::set / Object::get, building the StringName + Variant for you so a
// property can be poked by name without the raw Variant dance:
//
//     gd.set_int(self.owner, "value", 42)
//     v := gd.get_int(self.owner, "value")
//
// `prop` names are interned as STATIC StringNames — pass string literals only (never
// `fmt.ctprintf`-built cstrings; see the interning note in Ergonomics.odin).

// set_value sets `prop` on `obj` from an already-built Variant. `value` is NOT consumed —
// the caller still owns it (destroy non-POD Variants with gd.variant_destroy when done).
set_value :: proc "contextless" (obj: Object, prop: cstring, value: Variant) {
	object_set(obj, new_string_name_cstring(prop, true), value)
}

// set_int sets an integer property by name.
set_int :: proc "contextless" (obj: Object, prop: cstring, v: i64) {
	i := Int(v)
	set_value(obj, prop, variant_from_int(&i))
}

// set_float sets a float property by name.
set_float :: proc "contextless" (obj: Object, prop: cstring, v: f64) {
	f := Float(v)
	set_value(obj, prop, variant_from_float(&f))
}

// set_bool sets a bool property by name.
set_bool :: proc "contextless" (obj: Object, prop: cstring, v: bool) {
	b := v
	set_value(obj, prop, variant_from_bool(&b))
}

// set_string sets a String property by name (from an Odin cstring; may be dynamic — the
// temporary String and Variant are freed here).
set_string :: proc "contextless" (obj: Object, prop: cstring, v: cstring) {
	s := new_string_cstring(v)
	defer free_string(s)
	sv := variant_from_string(&s)
	defer variant_destroy(&sv)
	set_value(obj, prop, sv)
}

// get_value reads `prop` on `obj` as a raw Variant. The returned Variant is OWNED BY THE
// CALLER — destroy it with gd.variant_destroy when done (a no-op for POD content).
get_value :: proc "contextless" (obj: Object, prop: cstring) -> Variant {
	return object_get(obj, new_string_name_cstring(prop, true))
}

// get_int reads an integer property by name.
get_int :: proc "contextless" (obj: Object, prop: cstring) -> i64 {
	v := get_value(obj, prop)
	defer variant_destroy(&v) // the property may not actually be an int — free whatever came back
	return variant_to_int(&v)
}

// get_float reads a float property by name.
get_float :: proc "contextless" (obj: Object, prop: cstring) -> f64 {
	v := get_value(obj, prop)
	defer variant_destroy(&v)
	return variant_to_float(&v)
}

// get_bool reads a bool property by name.
get_bool :: proc "contextless" (obj: Object, prop: cstring) -> bool {
	v := get_value(obj, prop)
	defer variant_destroy(&v)
	return variant_to_bool(&v)
}

// get_string reads a String property by name and returns it as an Odin `string`, allocated
// in `context.allocator` (Odin scripts run with the script context set, so this Just Works
// inside script procs). NOTE: this is the one helper that needs a context (it allocates).
get_string :: proc(obj: Object, prop: cstring, allocator := context.allocator) -> string {
	v := get_value(obj, prop)
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
