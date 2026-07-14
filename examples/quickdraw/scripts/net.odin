package quickdraw

// Identity + the doors. Note what is NOT here anymore: the four transport
// forwards (on_packet/on_peer_left/on_net_up/on_net_down) are GENERATED —
// the kboot.Boot field on Quickdraw declares them — and the env-identity
// trio (QD_PORT / QD_NAME / QD_TOKEN, distinct seats for same-machine
// tests) rides Options.env = "QD". What's left is the game-shaped doors.

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kui "godot:kit/ui"

port :: proc(self: ^Quickdraw) -> int {
	return kboot.boot_port(&self.boot, DEFAULT_PORT)
}

// ---- the doors ----

@(gd_method)
quickdraw_on_host :: proc(self: ^Quickdraw) {
	if self.running {return}
	if !kboot.boot_host(&self.boot, port(self), kboot.boot_name(&self.boot, "gunslinger")) {
		gd.print_str("QD_HOST_FAIL")
		return
	}
	self.running = true
	kui.lobby_set_status(&self.boot.ui, fmt.tprintf("Hosting on :%d — waiting for gunslingers", port(self)))
	gd.print_str("QD_HOSTING")
}

@(gd_method)
quickdraw_on_join :: proc(self: ^Quickdraw) {
	if self.running {return}
	if !kboot.boot_join(&self.boot, "127.0.0.1", port(self), kboot.boot_token(&self.boot),
		kboot.boot_name(&self.boot, "gunslinger"), status = "Riding into town...") {
		return
	}
	self.running = true
	gd.print_str("QD_JOINING")
}

// The dedicated-marshal door (env role `serve`): an always-on arena — the
// server referees, simulates, and rewinds, but draws no iron. The sim lane's
// native shape.
quickdraw_on_serve :: proc(self: ^Quickdraw) {
	if self.running {return}
	if !kboot.boot_serve(&self.boot, port(self), kboot.boot_name(&self.boot, "gunslinger")) {
		gd.print_str("QD_HOST_FAIL")
		return
	}
	self.running = true
	gd.print_str("QD_SERVING")
}

@(gd_method)
quickdraw_on_start :: proc(self: ^Quickdraw) {
	if !self.ses.is_host || self.started {return}
	spawn_world(self)
}

@(gd_method)
quickdraw_on_chat :: proc(self: ^Quickdraw, text: gd.String) {
	if !self.running {return}
	kboot.boot_chat(&self.boot, text)
}
