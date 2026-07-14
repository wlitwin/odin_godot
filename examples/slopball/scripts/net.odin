package slopball

// Identity + the doors. Note what is NOT here anymore: the four transport
// forwards are GENERATED (the kboot.Boot field on Slopball declares them),
// and the env-identity trio (SLOP_PORT / SLOP_NAME / SLOP_TOKEN, distinct
// seats for same-machine tests) rides Options.env = "SLOP". What's left is
// the game-shaped doors.

import gd "godot:godot"
import kboot "godot:kit/boot"
import kui "godot:kit/ui"
import "core:fmt"

port :: proc(self: ^Slopball) -> int {
	return kboot.boot_port(&self.boot, DEFAULT_PORT)
}

// ---- the doors ----

@(gd_method)
slopball_on_host :: proc(self: ^Slopball) {
	if self.running {return}
	if !kboot.boot_host(&self.boot, port(self), kboot.boot_name(&self.boot, "kicker")) {
		gd.print_str("SB_HOST_FAIL")
		return
	}
	self.running = true
	kui.lobby_set_status(&self.boot.ui, fmt.tprintf("Hosting on :%d — waiting for kickers", port(self)))
	gd.print_str("SB_HOSTING")
}

@(gd_method)
slopball_on_join :: proc(self: ^Slopball) {
	if self.running {return}
	if !kboot.boot_join(&self.boot, "127.0.0.1", port(self), kboot.boot_token(&self.boot),
		kboot.boot_name(&self.boot, "kicker"), status = "Joining the pitch...") {
		return
	}
	self.running = true
	gd.print_str("SB_JOINING")
}

// The dedicated-server door (env role `serve`, no button): the kit flags the
// seat as infrastructure — this peer referees and simulates, but fields no
// kicker, holds no roster row, and never hands anyone the succession torch.
slopball_on_serve :: proc(self: ^Slopball) {
	if self.running {return}
	if !kboot.boot_serve(&self.boot, port(self), kboot.boot_name(&self.boot, "kicker")) {
		gd.print_str("SB_HOST_FAIL")
		return
	}
	self.running = true
	gd.print_str("SB_SERVING")
}

// Host presses Start (or the env role auto-fires it): build the world.
@(gd_method)
slopball_on_start :: proc(self: ^Slopball) {
	if !self.ses.is_host || self.started {return}
	spawn_world(self)
}

@(gd_method)
slopball_on_chat :: proc(self: ^Slopball, text: gd.String) {
	if !self.running {return}
	kboot.boot_chat(&self.boot, text)
}
