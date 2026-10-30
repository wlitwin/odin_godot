#+build !darwin
#+build !linux
package replay_claimball
import gd "godot:godot"
import rgd "godot:replay/godot"
online_native_init :: proc(self: ^ReplayClaimball, local: bool) -> (rgd.Party_Storage, bool) {return {}, gd.IS_WEB}
online_native_close :: proc(self: ^ReplayClaimball) {}
