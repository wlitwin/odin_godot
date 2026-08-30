//gd:extends Node
//gd:class ProcHolder
package phase4_scripts

// Deliberately has procedure-bearing state and NO reload hook. The core must keep
// this live instance on exactly its owning generation instead of rebinding it and
// turning `callback` into a dangling call after dlclose.

import gd "godot:godot"

proc_holder_value :: proc() -> int {
	when RELOAD_V == 3 {return 300}
	when RELOAD_V == 2 {return 200}
	return 100
}

ProcHolder :: struct {
	owner:    gd.Node,
	callback: proc() -> int,
}

proc_holder_ready :: proc(self: ^ProcHolder) {
	self.callback = proc_holder_value
}

@(gd_method)
proc_holder_cached_value :: proc(self: ^ProcHolder) -> int {
	return self.callback != nil ? self.callback() : -1
}

@(gd_method)
proc_holder_compiled_value :: proc(self: ^ProcHolder) -> int {
	return proc_holder_value()
}
