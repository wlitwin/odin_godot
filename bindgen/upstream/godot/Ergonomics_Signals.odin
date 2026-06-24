package godot

import gdext "godot:gdext"

// Ergonomic helpers for emitting signals by name — hand-written, mirrored in
// bindgen/upstream/godot/ so they survive binding regeneration.
//
// `emit` covers the zero-payload case via Object::emit_signal directly. `emit_args` covers
// the payload case the way scriptgen's generated emitters do: Object::emit_signal is a
// 0-arg bind, so we fetch the `emit_signal` MethodBind once and varargs-call it with a
// [signal_name, args…] Variant array.

// emit fires the named (zero-payload) signal on `obj`:
//
//     gd.emit(self.owner, "died")
//
// NOTE: this goes through the same `emit_signal` MethodBind varcall as `emit_args` (with no
// payload). The generated `object_emit_signal` can't be used: it ptrcalls, and Godot rejects
// ptrcall on the vararg `emit_signal` method ("ptrcall can't be used with vararg methods").
emit :: proc "contextless" (obj: Object, signal: cstring) -> Error {
	return emit_args(obj, signal)
}

@(private = "file")
_emit_signal_name: String_Name
@(private = "file")
_emit_bind: gdext.MethodBindPtr
@(private = "file")
_emit_ready: bool

@(private = "file")
_ensure_emit_bind :: proc "contextless" () {
	if _emit_ready {return}
	_emit_signal_name = new_string_name_cstring("emit_signal", true)
	_emit_bind = gdext.classdb_get_method_bind(object_name_ref(), &_emit_signal_name, 4047867050)
	_emit_ready = true
}

// _EMIT_MAX_ARGS bounds the on-stack VariantPtr scratch buffer (signal name + payload). 31
// payload values is far past any real signal arity.
@(private = "file")
_EMIT_MAX_ARGS :: 32

// emit_args fires the named signal on `obj` WITH a payload. Build the payload Variants with
// gd.variant_from(...) and pass them through:
//
//     v := i64(value)
//     gd.emit_args(self.owner, "collected", gd.variant_from(&v))
emit_args :: proc "contextless" (obj: Object, signal: cstring, args: ..Variant) -> Error {
	_ensure_emit_bind()
	if _emit_bind == nil {return .Failed}

	n := len(args) + 1
	if n > _EMIT_MAX_ARGS {return .Err_Parameter_Range_Error}

	sig_name := new_string_name_cstring(signal, true)
	sig_v := variant_from_string_name(&sig_name)

	buf: [_EMIT_MAX_ARGS]gdext.VariantPtr
	buf[0] = cast(gdext.VariantPtr)&sig_v
	for i in 0 ..< len(args) {
		buf[i + 1] = cast(gdext.VariantPtr)&args[i]
	}

	ret: Variant
	gdext.object_method_bind_call(_emit_bind, obj, &buf[0], i64(n), cast(gdext.VariantPtr)&ret, nil)
	err := variant_to_int(&ret)
	gdext.variant_destroy(cast(gdext.VariantPtr)&ret)
	gdext.variant_destroy(cast(gdext.VariantPtr)&sig_v)
	return Error(err)
}
