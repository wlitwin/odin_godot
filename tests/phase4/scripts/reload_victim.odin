//gd:extends Node
//gd:class ReloadVictim
package phase4_scripts

// A deliberately hostile reload hook: destroy the owning Godot object synchronously
// while the core is walking its pinned live-instance snapshot. This used to invalidate
// a raw pointer copied out from under live_lock. The snapshot pin now defers destruction
// of the Odin_Instance bookkeeping until the reload walk releases it.

import "godot:gdext"
import gd "godot:godot"

ReloadVictim :: struct {
	owner: gd.Node,
}

reload_victim_reload :: proc(self: ^ReloadVictim) {
	gdext.object_destroy(cast(gdext.ObjectPtr)self.owner)
}
