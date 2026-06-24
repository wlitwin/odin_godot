package godot

// Ergonomic logging / error helpers over the generated `gd_*` utility functions —
// hand-written (like Strings.odin / Variant.odin), and mirrored in
// bindgen/upstream/godot/ so they survive binding regeneration.
//
// Odin scripts are AOT-compiled NATIVE code with NO interpreter, so Godot's in-editor
// breakpoints / step / expression-eval do NOT work for them. The day-to-day debugging
// tools are: these print/error helpers, native `lldb`, and crash backtraces (see
// docs/debugging.md). These helpers collapse the cstring -> String -> Variant -> gd_*
// dance into one call:
//
//     gd.print("player ready")
//     gd.print_int(score)
//     gd.error("missing Hud node")        // editor: red error WITH the script context
//
// For FORMATTED output, format with Odin's `core:fmt` first, then print the result —
// keep `fmt` out of these helpers (it bloats the wasm/web footprint and pulls the temp
// allocator into otherwise contextless code):
//
//     import "core:fmt"
//     gd.print(fmt.ctprintf("score=%d at %v", score, pos))   // ctprintf -> cstring (temp)
//
// `ctprintf` returns a temp-allocated cstring (freed at the next `free_all(context.temp_allocator)`),
// which is exactly what `print` wants; `tprintf` returns a (temp) string — pass it via
// `gd.print_str` below if you have a `string` rather than a `cstring`.

// print logs `s` to the Godot output (stdout + the editor Output panel), like GDScript `print`.
print :: proc "contextless" (s: cstring) {
	str := new_string_cstring(s)
	v := variant_from_string(&str)
	gd_print(v)
}

// print_str logs an Odin `string` (e.g. the result of `fmt.tprintf`). Convenience over
// building the cstring yourself.
print_str :: proc "contextless" (s: string) {
	str := new_string_odin(s)
	v := variant_from_string(&str)
	gd_print(v)
}

// print_value logs any Variant directly (the engine stringifies it the same way GDScript
// `print(var)` does). Use when you already hold a Variant.
print_value :: proc "contextless" (v: Variant) {
	gd_print(v)
}

// print_int / print_float / print_bool build the matching Variant and log it.
print_int :: proc "contextless" (v: i64) {
	i := Int(v)
	gd_print(variant_from_int(&i))
}

print_float :: proc "contextless" (v: f64) {
	f := Float(v)
	gd_print(variant_from_float(&f))
}

print_bool :: proc "contextless" (v: bool) {
	b := v
	gd_print(variant_from_bool(&b))
}

// error pushes a Godot error: it shows in the editor's Output/Debugger in red WITH the
// originating script context, and is routed to any attached debugger. Use for genuine
// fault conditions (GDScript `push_error`).
error :: proc "contextless" (s: cstring) {
	str := new_string_cstring(s)
	v := variant_from_string(&str)
	gd_push_error(v)
}

// error_str — `error` for an Odin `string` (e.g. `fmt.tprintf` output).
error_str :: proc "contextless" (s: string) {
	str := new_string_odin(s)
	v := variant_from_string(&str)
	gd_push_error(v)
}

// warn pushes a Godot warning (yellow, non-fatal — GDScript `push_warning`).
warn :: proc "contextless" (s: cstring) {
	str := new_string_cstring(s)
	v := variant_from_string(&str)
	gd_push_warning(v)
}

// warn_str — `warn` for an Odin `string`.
warn_str :: proc "contextless" (s: string) {
	str := new_string_odin(s)
	v := variant_from_string(&str)
	gd_push_warning(v)
}
