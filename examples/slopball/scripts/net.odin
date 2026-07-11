package slopball

// Transport + identity, cavecrawl's shape: the four wire forwards, the
// Host/Join doors, and who this peer IS (SLOP_NAME / SLOP_TOKEN env override
// the defaults so same-machine tests pick distinct identities).

import gd "godot:godot"
import kboot "godot:kit/boot"
import netgd "godot:kit/netgd"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"

port :: proc() -> int {
	return gd.env_int("SLOP_PORT", DEFAULT_PORT)
}

my_name :: proc() -> string {
	n := gd.env_string("SLOP_NAME", "")
	return n == "" ? "kicker" : n
}

my_token :: proc() -> u64 {
	return ksave.token({env = "SLOP_TOKEN", path = "user://slop_token"})
}

// ---- the four transport forwards (netgd.Session_Wire owns what's behind them) ----

@(gd_method)
slopball_on_packet :: proc(self: ^Slopball, id: gd.Int, packet: gd.Packed_Byte_Array) {
	netgd.wire_receive(&self.boot.wire, id, packet)
}

@(gd_method)
slopball_on_peer_left :: proc(self: ^Slopball, id: gd.Int) {
	ksess.session_peer_disconnected(&self.ses, ksess.Peer_Id(id))
}

@(gd_method)
slopball_on_net_up :: proc(self: ^Slopball) {
	ksess.session_client_join(&self.ses)
}

@(gd_method)
slopball_on_net_down :: proc(self: ^Slopball) {
	ksess.session_peer_disconnected(&self.ses, ksess.HOST_PEER)
}

// ---- the doors ----

@(gd_method)
slopball_on_host :: proc(self: ^Slopball) {
	if self.running {return}
	if !gd.host(self.owner, port()) {
		kui.lobby_set_status(&self.boot.ui, "Could not host (port taken?)")
		gd.print_str("SB_HOST_FAIL")
		return
	}
	ksess.session_host_start(&self.ses, my_name())
	self.running = true
	kui.lobby_show_menu(&self.boot.ui, false, false)
	kui.lobby_set_status(&self.boot.ui, fmt.tprintf("Hosting on :%d — waiting for kickers", port()))
	kui.lobby_refresh(&self.boot.ui, &self.ses)
	kui.chat_show(&self.boot.chat, true)
	gd.print_str("SB_HOSTING")
}

@(gd_method)
slopball_on_join :: proc(self: ^Slopball) {
	if self.running {return}
	if !gd.join(self.owner, "127.0.0.1", port()) {
		kui.lobby_set_status(&self.boot.ui, "Could not start joining")
		return
	}
	ksess.session_client_start(&self.ses, my_token(), my_name())
	self.running = true
	kui.lobby_show_menu(&self.boot.ui, false, false)
	kui.lobby_set_status(&self.boot.ui, "Joining the pitch...")
	kui.chat_show(&self.boot.chat, true)
	gd.print_str("SB_JOINING")
}

// The dedicated-server door (env role `serve`, no button): the kit flags the
// seat as infrastructure — this peer referees and simulates, but fields no
// kicker, holds no roster row, and never hands anyone the succession torch.
slopball_on_serve :: proc(self: ^Slopball) {
	if self.running {return}
	if !kboot.boot_serve(&self.boot, port(), my_name()) {
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
