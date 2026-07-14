package speedball

// Transport + identity, the standard shape: four wire forwards, the doors,
// and who this peer IS (SPB_NAME / SPB_TOKEN pick distinct identities in
// same-machine tests).

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import netgd "godot:kit/netgd"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import kui "godot:kit/ui"

port :: proc() -> int {
	return gd.env_int("SPB_PORT", DEFAULT_PORT)
}

my_name :: proc() -> string {
	n := gd.env_string("SPB_NAME", "")
	return n == "" ? "kicker" : n
}

my_token :: proc() -> u64 {
	return ksave.token({env = "SPB_TOKEN", path = "user://spb_token"})
}

// ---- the four transport forwards ----

@(gd_method)
speedball_on_packet :: proc(self: ^Speedball, id: gd.Int, packet: gd.Packed_Byte_Array) {
	netgd.wire_receive(&self.boot.wire, id, packet)
}

@(gd_method)
speedball_on_peer_left :: proc(self: ^Speedball, id: gd.Int) {
	ksess.session_peer_disconnected(&self.ses, ksess.Peer_Id(id))
}

@(gd_method)
speedball_on_net_up :: proc(self: ^Speedball) {
	ksess.session_client_join(&self.ses)
}

@(gd_method)
speedball_on_net_down :: proc(self: ^Speedball) {
	ksess.session_peer_disconnected(&self.ses, ksess.HOST_PEER)
}

// ---- the doors ----

@(gd_method)
speedball_on_host :: proc(self: ^Speedball) {
	if self.running {return}
	if !gd.host(self.owner, port()) {
		kui.lobby_set_status(&self.boot.ui, "Could not host (port taken?)")
		gd.print_str("SPB_HOST_FAIL")
		return
	}
	ksess.session_host_start(&self.ses, my_name())
	self.running = true
	kui.lobby_show_menu(&self.boot.ui, false, false)
	kui.lobby_set_status(&self.boot.ui, fmt.tprintf("Hosting on :%d — waiting for kickers", port()))
	kui.lobby_refresh(&self.boot.ui, &self.ses)
	kui.chat_show(&self.boot.chat, true)
	gd.print_str("SPB_HOSTING")
}

@(gd_method)
speedball_on_join :: proc(self: ^Speedball) {
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
	gd.print_str("SPB_JOINING")
}

// The dedicated-marshal door (env role `serve`): an always-on arena — the
// server referees, simulates, and rewinds, but draws no iron. The sim lane's
// native shape.
speedball_on_serve :: proc(self: ^Speedball) {
	if self.running {return}
	if !kboot.boot_serve(&self.boot, port(), my_name()) {
		gd.print_str("SPB_HOST_FAIL")
		return
	}
	self.running = true
	gd.print_str("SPB_SERVING")
}

@(gd_method)
speedball_on_start :: proc(self: ^Speedball) {
	if !self.ses.is_host || self.started {return}
	spawn_world(self)
}

@(gd_method)
speedball_on_chat :: proc(self: ^Speedball, text: gd.String) {
	if !self.running {return}
	kboot.boot_chat(&self.boot, text)
}
