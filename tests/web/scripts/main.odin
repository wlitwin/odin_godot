//gd:extends Node
//gd:class Main
package web_scripts

// The web milestone script. Attached (via the res://main.odin resource stub) to the
// Main node of main.tscn. In the browser its `ready` lifecycle runs real Odin code
// that was AOT-compiled into the wasm SIDE_MODULE, and prints sentinels through
// Godot's `print` — which the web runtime routes to the browser's JS console.

import gd "godot:godot"

Main :: struct {
	owner: gd.Node,
}

main_ready :: proc(self: ^Main) {
	web_print("WEB_RAN")
	if main_add(self, 2, 3) == 5 {
		web_print("WEB_ASSERT_OK")
	} else {
		web_print("WEB_ASSERT_FAIL")
	}
}

@(gd_method)
main_add :: proc(self: ^Main, a, b: int) -> int {
	return a + b
}

// Print a line through Godot (-> browser console). Not a `^Main` method, so scriptgen
// ignores it.
web_print :: proc(s: string) {
	gs := gd.new_string_odin(s)
	v := gd.variant_from_string(&gs)
	gd.gd_print(v)
}
