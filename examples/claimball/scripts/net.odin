package claimball

// Identity + the doors. Note what is NOT here anymore: the four transport
// forwards are GENERATED (the kboot.Boot field on Claimball declares them),
// and the env-identity trio (CLB_PORT / CLB_NAME / CLB_TOKEN, distinct
// seats for same-machine tests) rides Options.env = "CLB". What's left is
// the game-shaped doors.

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kui "godot:kit/ui"

port :: proc(self: ^Claimball) -> int {
	return kboot.boot_port(&self.boot, DEFAULT_PORT)
}

// ---- the doors ----

@(gd_method)
claimball_on_host :: proc(self: ^Claimball) {
	if self.running {return}
	if !kboot.boot_host(&self.boot, port(self), kboot.boot_name(&self.boot, "kicker")) {
		gd.print_str("CLB_HOST_FAIL")
		return
	}
	self.running = true
	kui.lobby_set_status(&self.boot.ui, fmt.tprintf("Hosting on :%d — waiting for kickers", port(self)))
	gd.print_str("CLB_HOSTING")
}

@(gd_method)
claimball_on_join :: proc(self: ^Claimball) {
	if self.running {return}
	if !kboot.boot_join(&self.boot, "127.0.0.1", port(self), kboot.boot_token(&self.boot),
		kboot.boot_name(&self.boot, "kicker"), status = "Joining the pitch...") {
		return
	}
	self.running = true
	gd.print_str("CLB_JOINING")
}

// The dedicated-marshal door (env role `serve`): an always-on arena — the
// server referees, simulates, and rewinds, but draws no iron. The sim lane's
// native shape.
claimball_on_serve :: proc(self: ^Claimball) {
	if self.running {return}
	if !kboot.boot_serve(&self.boot, port(self), kboot.boot_name(&self.boot, "kicker")) {
		gd.print_str("CLB_HOST_FAIL")
		return
	}
	self.running = true
	gd.print_str("CLB_SERVING")
}

@(gd_method)
claimball_on_start :: proc(self: ^Claimball) {
	if !self.ses.is_host || self.started {return}
	spawn_world(self)
}

@(gd_method)
claimball_on_chat :: proc(self: ^Claimball, text: gd.String) {
	if !self.running {return}
	kboot.boot_chat(&self.boot, text)
}
