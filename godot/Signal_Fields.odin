package godot

// Typed signal DECLARATIONS as struct fields — hand-written and owned here (binding
// regeneration only rewrites *.gen.odin).
//
// A script declares a signal by giving its struct a field of one of these marker types
// (arity-suffixed: Signal0 … Signal4). The FIELD NAME is the signal name; the type
// parameters are the payload types; the optional `gd:"args=..."` tag names the payload
// (comma-separated, one name per parameter — omitted names synthesize as arg0, arg1, …):
//
//     Coin :: struct {
//         owner:     Area2d,
//         died:      Signal0,
//         collected: Signal1(int) `gd:"args=value"`,
//         hit:       Signal2(int, ^Node2d) `gd:"args=amount,who"`,
//     }
//
// The runtime registration walk (runtime/register_class.odin) recognizes these fields by
// TYPE (no tag required) and registers the signal with the engine; scriptgen emits a typed
// `<struct_snake>_emit_<field>` helper per signal field. Emission by name (`gd.emit` /
// `gd.emit_args`) and connection (`gd.connect*` / `@(gd_connect)`) are unchanged.
//
// The `_marker` phantom pointer is never allocated or dereferenced — it exists so the
// payload typeids are recoverable STRUCTURALLY from the field's type info (the pointee
// struct's field types), not by parsing a rendered type name. Cost: one nil pointer
// (pointer-size bytes) per declared signal, which also keeps every signal field at a
// distinct offset (a zero-size marker would fold).
//
// (The unparametrized `Signal` name is taken by the Variant signal HANDLE in Variant.odin —
// a value you store/pass/export — hence the arity-suffixed family. Odin parametric structs
// have a fixed parameter count, so each arity is its own type; 4 covers well past any
// signal in the tree, and mirrors how far GDScript payloads sanely go.)

Signal0 :: struct {
	_marker: ^struct {},
}

Signal1 :: struct($A: typeid) {
	_marker: ^struct {
		a: A,
	},
}

Signal2 :: struct($A, $B: typeid) {
	_marker: ^struct {
		a: A,
		b: B,
	},
}

Signal3 :: struct($A, $B, $C: typeid) {
	_marker: ^struct {
		a: A,
		b: B,
		c: C,
	},
}

Signal4 :: struct($A, $B, $C, $D: typeid) {
	_marker: ^struct {
		a: A,
		b: B,
		c: C,
		d: D,
	},
}
