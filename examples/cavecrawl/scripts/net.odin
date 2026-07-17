package cavecrawl_scripts

// Transport + identity: how packets leave and arrive, who this peer IS, and
// the Host/Join buttons that bring the wire up. Everything session-shaped
// stays in kit/session — this file only moves bytes and reads the env.
//
// Identity: CAVE_NAME / CAVE_TOKEN env override the defaults so tests (and
// impatient friends sharing a machine) can pick who they are; otherwise the
// token persists in user://cave_token — reconnects, resumed saves,
// everything rides on keeping it.

import gd "godot:godot"
import "godot:gdext"
import kboot "godot:kit/boot"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import ksave "godot:kit/save"
import ksess "godot:kit/session"
import steamgd "godot:kit/steamgd"
import kui "godot:kit/ui"
import "core:fmt"
import "core:strconv"

port :: proc() -> int {
	if p, ok := strconv.parse_int(gd.env_string("CAVE_PORT", "")); ok {
		return p
	}
	return DEFAULT_PORT
}

my_name :: proc(self: ^CaveLobby) -> string {
	n := gd.env_string("CAVE_NAME", "")
	if n == "" && self.steam_on {
		n = steamgd.persona_name() // your Steam name IS your name
	}
	if n == "" {
		n = "spelunker"
	}
	return n
}

my_token :: proc() -> u64 {
	// No per_instance: this game has saves and successions to reclaim, so the
	// file token stays pure; same-machine tests pass distinct CAVE_TOKENs.
	return ksave.token({env = "CAVE_TOKEN", path = "user://cave_token"})
}

// (The four transport forwards — on_packet/on_peer_left/on_net_up/
// on_net_down — are GENERATED now: the kboot.Boot field on CaveLobby
// declares them, and netgd.Session_Wire owns everything behind them.)

// Host: show a player the door, with a run-scoped ban — the two-call kick:
// the session unseats (and tells) them; the wire severs their socket.
@(gd_method)
cave_lobby_kick :: proc(self: ^CaveLobby, player: gd.Int) {
	if !self.ses.is_host {return}
	target := knet.Player_Id(player)
	name := "someone"
	if p, ok := ksess.session_player(&self.ses, target); ok {
		name = p.name
	}
	was, ok := ksess.session_kick(&self.ses, target, ban = true)
	if !ok {return}
	netgd.wire_drop(&self.boot.wire, was) // deferred: the KICKED message flushes first
	kcomms.comms_system(&self.comms, fmt.tprintf("%s was shown the door", name))
	gd.print_str(fmt.tprintf("CAVE_KICKED player=%d", u64(target)))
}

// Rejoin a run whose host CHANGED under us (takeover): drop the dead
// transport and our stale world, then join the same address with the same
// token — the new host's WELCOME + SES_WORLD give us ourselves back.
@(gd_method)
cave_lobby_on_rejoin :: proc(self: ^CaveLobby) {
	cave_rejoin_to(self, "127.0.0.1", port())
}

// The dance's words — the kit already acted (the dial, the caps, the heir
// arms); each arm narrates. The acid pins the chase receipts here.
cave_lobby_migrating :: proc(self: ^CaveLobby, step: kboot.Migrate_Step, target: string, try: int) {
	_ = target
	switch step {
	case .Taking_Over:
		gd.print_str("CAVE_TORCH_MINE")
	case .Chasing:
		gd.print_str(fmt.tprintf("CAVE_CHASE_TORCH try=%d", try))
		kui.lobby_set_status(&self.boot.ui, "Rejoining the cave...")
		gd.print_str("CAVE_REJOINING")
	case .Knocking: // no web build of the cave (yet)
	case .No_Torch, .Gave_Up:
		kui.lobby_set_status(&self.boot.ui, "The torch went out — this run is over")
	case .Chase_Failed:
		kui.lobby_set_status(&self.boot.ui, "Could not start rejoining")
	case .No_Backup:
		kui.lobby_set_status(&self.boot.ui, "No backup to carry")
		gd.print_str("CAVE_TAKEOVER_FAIL no-backup")
	case .Raise_Failed:
		gd.print_str("CAVE_HOST_FAIL")
	case .Resume_Corrupt:
		gd.print_str("CAVE_TAKEOVER_FAIL snapshot")
	}
}

cave_rejoin_to :: proc(self: ^CaveLobby, addr: string, to_port: int) {
	if !self.running || self.ses.is_host || !self.host_gone {return}
	kboot.boot_entities_wipe(&self.boot) // census-driven: _freed hooks + the wiped half
	gd.multiplayer_clear_peer(self.owner)
	if !gd.join(self.owner, fmt.ctprintf("%s", addr), to_port) {
		kui.lobby_set_status(&self.boot.ui, "Could not start rejoining")
		return
	}
	ksess.session_client_start(&self.ses, my_token(), my_name(self))
	self.host_gone = false
	kui.lobby_set_status(&self.boot.ui, "Rejoining the cave...")
	gd.print_str("CAVE_REJOINING")
}

@(gd_method)
cave_lobby_on_host :: proc(self: ^CaveLobby) {
	if self.running {return}
	if self.steam_on {
		// Hosting completes on the lobby_created signal.
		steamgd.create_lobby(4)
		kui.lobby_set_status(&self.boot.ui, "Creating a Steam lobby...")
		gd.print_str("CAVE_STEAM_LOBBY_PENDING")
		return
	}
	if !gd.host(self.owner, port()) {
		kui.lobby_set_status(&self.boot.ui, "Could not host (port taken?)")
		gd.print_str("CAVE_HOST_FAIL")
		return
	}
	begin_hosting(self)
}

// Everything hosting means AFTER a transport is up — shared verbatim by the
// ENet path (gd.host above) and the Steam path (lobby_created below): the
// session cannot tell the transports apart, which is the whole point.
begin_hosting :: proc(self: ^CaveLobby) {
	ksess.session_host_start(&self.ses, my_name(self))
	// The ceremony's shape (cavecrawl raises its own transports — Steam is
	// why — so the boot doors never saw this run's port/token/name).
	kboot.boot_succ_config(&self.boot, false, port(), "", my_token(), my_name(self))
	self.cols = kcombat.combat_columns(&self.ses) // the ledger, on the scoreboard
	self.slain_col = ksess.session_stat_column(&self.ses, "slain") // the game's own column
	self.running = true
	kui.lobby_show_menu(&self.boot.ui, false, false)
	kui.lobby_set_status(&self.boot.ui, self.steam_on ? "Hosting a Steam lobby — invite friends via the overlay" : fmt.tprintf("Hosting on :%d — waiting for friends", port()))
	kui.lobby_refresh(&self.boot.ui, &self.ses)
	kui.chat_show(&self.boot.chat, true)
	gd.print_str("CAVE_HOSTING")
}

@(gd_method)
cave_lobby_on_join :: proc(self: ^CaveLobby) {
	if self.running {return}
	if self.steam_on {
		// Steam joins arrive through the overlay (join_requested below).
		kui.lobby_set_status(&self.boot.ui, "Accept a Steam invite to join (Shift+Tab)")
		return
	}
	if !gd.join(self.owner, "127.0.0.1", port()) {
		kui.lobby_set_status(&self.boot.ui, "Could not start joining")
		return
	}
	begin_joining(self)
}

begin_joining :: proc(self: ^CaveLobby) {
	ksess.session_client_start(&self.ses, my_token(), my_name(self))
	kboot.boot_succ_config(&self.boot, false, port(), "", my_token(), my_name(self))
	self.running = true
	kui.lobby_show_menu(&self.boot.ui, false, false)
	kui.lobby_set_status(&self.boot.ui, "Joining the cave...")
	kui.chat_show(&self.boot.chat, true)
	gd.print_str("CAVE_JOINING")
}

// ---- the Steam lobby signals (see kit/steamgd's header for the flow) ----

@(gd_method)
cave_lobby_on_lobby_created :: proc(self: ^CaveLobby, result: gd.Int, lobby_id: gd.Int) {
	if int(result) != 1 {
		kui.lobby_set_status(&self.boot.ui, "Steam could not make the lobby")
		gd.print_str("CAVE_STEAM_LOBBY_FAIL")
		return
	}
	self.steam_lobby = u64(lobby_id)
	if !steamgd.host_peer(self.owner) {
		kui.lobby_set_status(&self.boot.ui, "Steam peer failed")
		return
	}
	begin_hosting(self)
	steamgd.invite_overlay(self.steam_lobby)
}

@(gd_method)
cave_lobby_on_lobby_joined :: proc(self: ^CaveLobby, lobby_id: gd.Int, _perms: gd.Int, _locked: gd.Bool, _response: gd.Int) {
	owner := steamgd.lobby_owner(u64(lobby_id))
	if owner == 0 || owner == steamgd.my_steam_id() {
		return // our own lobby (hosts join what they create), or no Steam
	}
	self.steam_lobby = u64(lobby_id)
	if !steamgd.client_peer(self.owner, owner) {
		kui.lobby_set_status(&self.boot.ui, "Steam peer failed")
		return
	}
	// connected_to_server will fire -> the wire's on_net_up seats us.
	begin_joining(self)
}

@(gd_method)
cave_lobby_on_join_requested :: proc(self: ^CaveLobby, lobby_id: gd.Int, _friend: gd.Int) {
	steamgd.join_lobby(u64(lobby_id)) // the overlay's "Join Game" lands here
}
