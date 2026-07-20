package kit_steamgd

// The Steam TRANSPORT record — Steam's answer to kit/netgd's control-plane
// checklist (kit/netgd/transport.odin). Before this file existed, Steam was
// the transport that stopped at "install a peer": no begin_* pair, no kit/boot
// door, no per-peer introspection, no rendezvous — so a Steam game hand-wrote
// the two-step ceremony every other transport had wrapped, and every kit
// feature keyed on a door (the lobby ritual, the succession config, the
// control-plane pump) simply did not happen for it.
//
// WHERE THE LOBBY FITS. Steam's ceremony is asynchronous in a way ENet's is
// not: you ask for a lobby, and the answer arrives on a signal. That half
// stays where it belongs — in the game's signal handlers (steamgd.odin's flow
// comment walks it) — because it is a Steam conversation, not a transport
// verb. What the doors below take is the ENDPOINT that conversation produces:
//
//     // on_lobby_created(result, lobby_id):   host
//     kboot.boot_open_host(&self.boot, &ksteam.TRANSPORT, {}, name)
//     ksteam.invite_overlay(u64(lobby_id))
//
//     // on_lobby_joined(lobby_id, ...):       guest
//     kboot.boot_open_join(&self.boot, &ksteam.TRANSPORT, endpoint_of(u64(lobby_id)), token, name)
//
// From there everything above the wire is the ENet path verbatim.

import ksess "godot:kit/session"
import netgd "godot:kit/netgd"

// The record. Three slots are deliberately nil, and each nil is a DECLARED
// degradation rather than an omission:
//
//   pump   — nothing to service. GodotSteam's peer is polled inside the
//            engine's own multiplayer step, exactly like ENet's.
//   close  — the peer is replaced by the next install, same as ENet; the part
//            that outlives it is LOBBY MEMBERSHIP, and the lobby id belongs to
//            the game (a signal handed it over). Call leave_lobby with it on
//            the way back to the menu.
//   link   — GodotSteam exposes no per-peer rtt/jitter/loss through the
//            MultiplayerPeer surface, so the netgraph blanks its link row
//            instead of printing a confident zero. (The session's own ping
//            column still works — it is measured, not asked for.)
//   address— THE ONE THAT MATTERS: with no verified way to ask which steam id
//            is behind a multiplayer peer, no torch can name an heir, so
//            `rendezvous` is .None and host migration is honestly OFF on
//            Steam rather than armed-and-silently-absent (succession_torch
//            says so once, naming this transport). Filling it is a small
//            change — GodotSteam's SteamMultiplayerPeer exposes the mapping on
//            builds that have it — but it cannot be verified from this repo
//            (no Steam client, no linked extension, all calls by name), and a
//            migration path that has never once run is worse than a stated
//            absence. Fill the slot against a real build, add the
//            Rendezvous_Kind arm, and Steam migrates.
TRANSPORT := netgd.Transport {
	name       = "steam",
	rendezvous = .None,
	open_host  = steam_open_host,
	open_join  = steam_open_join,
}

// The lobby id a signal handed you → the endpoint its owner answers on.
// (Steam addresses peers by steam id, not by lobby: the lobby is the
// phonebook, the owner's id is the number.)
endpoint_of :: proc(lobby_id: u64) -> netgd.Endpoint {
	return {peer_id = lobby_owner(lobby_id)}
}

@(private = "file")
steam_open_host :: proc(wire: ^netgd.Session_Wire, at: netgd.Endpoint, name: string, token: u64, dedicated: bool) -> bool {
	if !host_peer(wire.node) {
		return false
	}
	ksess.session_host_start(wire.ses, name, token, dedicated)
	return true
}

@(private = "file")
steam_open_join :: proc(wire: ^netgd.Session_Wire, at: netgd.Endpoint, name: string, token: u64, spectate: bool) -> bool {
	if at.peer_id == 0 {
		// The lobby answered with no owner (a dead or unjoined lobby): refuse
		// at the door rather than installing a peer pointed at nobody, which
		// would surface much later as an unexplained join timeout.
		return false
	}
	if !client_peer(wire.node, at.peer_id) {
		return false
	}
	ksess.session_client_start(wire.ses, token, name, spectate)
	return true
}

