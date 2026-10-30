#+build !darwin
#+build !linux
package replay_quickdraw
import gd "godot:godot"
import rgd "godot:replay/godot"
online_native_init :: proc(self: ^ReplayQuickdraw, local: bool) -> (rgd.Party_Storage, bool) {return {}, gd.IS_WEB}
online_native_close :: proc(self: ^ReplayQuickdraw) {}
