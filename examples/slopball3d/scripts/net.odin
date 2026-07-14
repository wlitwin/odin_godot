package slopball3d

// Identity + the doors. Note what is NOT here anymore: the four transport
// forwards are GENERATED (the kboot.Boot field on Slopball3 declares them),
// and the env-identity trio (SLOP3_PORT / SLOP3_NAME / SLOP3_TOKEN, distinct
// seats for same-machine tests) rides Options.env = "SLOP3". What's left is
// the game-shaped doors.

import gd "godot:godot"
import kboot "godot:kit/boot"
import kui "godot:kit/ui"
import "core:fmt"

port :: proc(self: ^Slopball3) -> int {
	return kboot.boot_port(&self.boot, DEFAULT_PORT)
}

// ---- the doors ----

@(gd_method)
slopball3_on_host :: proc(self: ^Slopball3) {
	if self.running {return}
	if !kboot.boot_host(&self.boot, port(self), kboot.boot_name(&self.boot, "kicker")) {
		gd.print_str("SB3_HOST_FAIL")
		return
	}
	self.running = true
	kui.lobby_set_status(&self.boot.ui, fmt.tprintf("Hosting on :%d — waiting for kickers", port(self)))
	gd.print_str("SB3_HOSTING")
}

@(gd_method)
slopball3_on_join :: proc(self: ^Slopball3) {
	if self.running {return}
	if !kboot.boot_join(&self.boot, "127.0.0.1", port(self), kboot.boot_token(&self.boot),
		kboot.boot_name(&self.boot, "kicker"), status = "Joining the pitch...") {
		return
	}
	self.running = true
	gd.print_str("SB3_JOINING")
}

// Host presses Start (or the env role auto-fires it): build the world.
@(gd_method)
slopball3_on_start :: proc(self: ^Slopball3) {
	if !self.ses.is_host || self.started {return}
	spawn_world(self)
}

@(gd_method)
slopball3_on_chat :: proc(self: ^Slopball3, text: gd.String) {
	if !self.running {return}
	kboot.boot_chat(&self.boot, text)
}
