//gd:extends Node
//gd:class EditorLifetimeGuard
//gd:tool
package reload_owner
import gd "godot:godot"
EditorLifetimeGuard :: struct {owner: gd.Node}
guard_finalized: int
editor_lifetime_guard_finalize :: proc(self: ^EditorLifetimeGuard) {guard_finalized+=1}
@(gd_method)
editor_lifetime_guard_count :: proc(self: ^EditorLifetimeGuard) -> i64 {return i64(guard_finalized)}
