package kit_netgd

// transport — the CONTROL plane, named once.
//
// The DATA plane was always abstract: every transport rides SceneMultiplayer's
// raw-bytes path, so steady-state traffic is byte-identical over ENet, WebRTC,
// or Steam and nothing above wire_send can tell them apart. The CONTROL plane
// — open, pump, close, who-is-that-peer — was the opposite: a parallel door-set
// per transport, spread across three layers, each answering a slightly
// different set of questions. A fourth transport had to touch a peer
// installer, a begin_* pair, two-to-four boot doors, boot_succ_config, a
// rendezvous flavor, a link-quality equivalent, and a per-transport decision
// about who pumps it — and NOTHING made that list visible. Steam answered
// three of the seven and silently skipped the rest for months.
//
// So the list is a TYPE now. One record per transport, filled once:
//
//     open_host / open_join   REQUIRED — bring the transport up AND start the
//                             session over it (the two-step every game used to
//                             repeat by hand). false = the transport refused.
//     pump                    optional — nil means the engine polls it (ENet,
//                             Steam). WebRTC's signaling socket is ours to
//                             service, so it fills this and kit/boot drives it
//                             every frame; a game no longer has to know which
//                             kind it is holding.
//     close                   optional — nil means nothing is held open past
//                             the peer itself. Fold whatever a fresh open_*
//                             would collide with.
//     link                    optional — the transport's own per-peer rtt /
//                             jitter / loss. nil is NOT zero: nil means "no
//                             story", and the netgraph shows blanks instead of
//                             a confident lie.
//     address                 optional — the rendezvous handle for a peer, as
//                             this transport addresses it. This is the slot
//                             host migration stands on: a transport with no
//                             address story cannot light a torch, and the
//                             torch says so once (succession.odin).
//     rendezvous              which torch kind `address` feeds. .None = this
//                             transport cannot migrate, stated in the record
//                             rather than discovered at 2am.
//
// The record is the checklist. A new transport that leaves a slot nil has
// DECLARED a degradation instead of inheriting one by omission, and the
// degradation is the same one every time (documented at the slot, not in the
// caller).
//
// On the no-package-globals rule this package's header states: it forbids
// per-SESSION state in package scope, because two sessions in one process
// would fight over it. These records hold no session state at all — they are
// constant tables of procs, and every verb takes the ^Session_Wire that owns
// the state. That is why there is no `user: rawptr` slot: a transport needing
// its own state would put it on the wire it is handed, where teardown can
// already see it.

import gd "godot:godot"
import ksess "godot:kit/session"
import "core:mem"

// WHERE a run lives, in whatever flavor its transport understands. One record
// for both doors — the host fills what it BINDS, the joiner what it DIALS —
// and the same nouns the succession torch carries, so a survivor's decoded
// Rendezvous becomes an Endpoint by hand-off rather than by translation.
//
// The string fields are cstrings because everything downstream of them is an
// engine call; they are VIEWS of the caller's storage and the doors consume
// them synchronously (nothing here outlives the call).
Endpoint :: struct {
	addr:      cstring, // native: the host's address (join) · web: the relay url (both)
	port:      int, // native: the port to bind or dial
	room:      cstring, // web: the room code — RESERVED on host (empty = let the relay assign), knocked on join
	peer_id:   u64, // steam: the host's steam id (join) — the lobby ceremony hands it over
	max_peers: int, // host: the seat cap (0 = the transport's own default)
}

Transport :: struct {
	name:       string, // "enet" / "webrtc" / "steam" — status lines and logs
	rendezvous: Rendezvous_Kind, // the torch flavor `address` feeds (.None = no migration on this transport)
	open_host:  proc(wire: ^Session_Wire, at: Endpoint, name: string, token: u64, dedicated: bool) -> bool,
	open_join:  proc(wire: ^Session_Wire, at: Endpoint, name: string, token: u64, spectate: bool) -> bool,
	pump:       proc(wire: ^Session_Wire),
	close:      proc(wire: ^Session_Wire),
	link:       proc(wire: ^Session_Wire, peer: ksess.Peer_Id) -> (rtt_ms, jitter_ms, loss_pct: f64, ok: bool),
	address:    proc(wire: ^Session_Wire, peer: ksess.Peer_Id, allocator: mem.Allocator) -> (addr: string, ok: bool),
}

// ---- the doors -------------------------------------------------------------

// Host over `t`. The wire REMEMBERS the transport, which is how every later
// verb (pump, close, link, address, the torch) stops needing to be told again
// — the single fact that dissolved the per-transport smear.
transport_host :: proc(
	wire: ^Session_Wire,
	t: ^Transport,
	at: Endpoint,
	name: string,
	token: u64 = 0,
	dedicated := false,
) -> bool {
	assert(t != nil && t.open_host != nil, "a Transport must fill open_host — see kit/netgd/transport.odin")
	if !t.open_host(wire, at, name, token, dedicated) {
		return false
	}
	wire.transport = t
	return true
}

// Join over `t`. `spectate` takes a receive-only seat (ksess.Player.spectator).
transport_join :: proc(
	wire: ^Session_Wire,
	t: ^Transport,
	at: Endpoint,
	name: string,
	token: u64,
	spectate := false,
) -> bool {
	assert(t != nil && t.open_join != nil, "a Transport must fill open_join — see kit/netgd/transport.odin")
	if !t.open_join(wire, at, name, token, spectate) {
		return false
	}
	wire.transport = t
	return true
}

// Which transport this wire rides. A wire opened the RAW way (gd.host /
// gd.webrtc_host by hand, then wire_attach) never named one — it reads as
// ENet, which is safe rather than presumptuous: every ENet verb below
// class-checks the installed peer and answers ok=false when it is something
// else, so the raw path degrades exactly as it did before this record existed.
transport_of :: proc(wire: ^Session_Wire) -> ^Transport {
	return wire.transport if wire.transport != nil else &ENET
}

// The per-frame control-plane pump. kit/boot calls this every frame for every
// game; a transport that needs no servicing costs one nil check. (Before this
// existed, a browser game that opened its room through a boot door had to know
// that WebRTC — alone among transports — needed web_poll hand-called from
// process(), and nothing said so.)
transport_service :: proc(wire: ^Session_Wire) {
	t := transport_of(wire)
	if t.pump != nil {
		t.pump(wire)
	}
}

// Fold whatever the transport holds open, so a fresh transport_host/join can
// bind clean (the retry after a failed join, a successor raising a new room).
transport_close :: proc(wire: ^Session_Wire) {
	t := transport_of(wire)
	if t.close != nil {
		t.close(wire)
	}
}

// The transport's own view of a peer's link — see wire_link_quality, which is
// the name games call this by.
transport_link :: proc(wire: ^Session_Wire, peer: ksess.Peer_Id) -> (rtt_ms, jitter_ms, loss_pct: f64, ok: bool) {
	t := transport_of(wire)
	if t.link == nil {
		return
	}
	return t.link(wire, peer)
}

// The rendezvous handle for `peer`, as THIS transport addresses it — what a
// torch carries so survivors can find the heir. ok=false means this transport
// has no address story (succession says so once and leaves migration honestly
// absent) or the peer is unknown.
transport_address :: proc(
	wire: ^Session_Wire,
	peer: ksess.Peer_Id,
	allocator := context.temp_allocator,
) -> (addr: string, ok: bool) {
	t := transport_of(wire)
	if t.address == nil {
		return "", false
	}
	return t.address(wire, peer, allocator)
}

// ---- ENet ------------------------------------------------------------------

ENET := Transport {
	name       = "enet",
	rendezvous = .Native_Addr,
	open_host  = enet_open_host,
	open_join  = enet_open_join,
	// pump: the engine polls ENet inside its own multiplayer step.
	// close: the peer IS the whole holding; installing a new one replaces it.
	link       = enet_link,
	address    = enet_address,
}

@(private = "file")
enet_open_host :: proc(wire: ^Session_Wire, at: Endpoint, name: string, token: u64, dedicated: bool) -> bool {
	if !gd.host(wire.node, at.port, at.max_peers if at.max_peers > 0 else 32) {
		return false
	}
	ksess.session_host_start(wire.ses, name, token, dedicated)
	return true
}

@(private = "file")
enet_open_join :: proc(wire: ^Session_Wire, at: Endpoint, name: string, token: u64, spectate: bool) -> bool {
	if !gd.join(wire.node, at.addr, at.port) {
		return false
	}
	ksess.session_client_start(wire.ses, token, name, spectate)
	return true
}

@(private = "file")
enet_link :: proc(wire: ^Session_Wire, peer: ksess.Peer_Id) -> (rtt_ms, jitter_ms, loss_pct: f64, ok: bool) {
	return enet_peer_stats(wire.node, peer)
}

@(private = "file")
enet_address :: proc(
	wire: ^Session_Wire,
	peer: ksess.Peer_Id,
	allocator: mem.Allocator,
) -> (addr: string, ok: bool) {
	return peer_address(wire.node, peer, allocator)
}

// ---- OFFLINE (single player) ------------------------------------------------
//
// The same game, alone: NO network transport (ENet is absent from the web
// export; there is nobody to reach anyway), but the session still needs to be
// a valid HOST — an OfflineMultiplayerPeer gives it unique id 1 and a place
// for its per-tick broadcasts to cleanly reach nobody. Without it,
// send_bytes with no peer installed spams "peer isn't set" every tick — the
// gotcha every game's hand-rolled `on_single` existed to re-derive. Works
// identically on native and web; rendezvous .None (nobody to migrate to).
OFFLINE := Transport {
	name       = "offline",
	rendezvous = .None,
	open_host  = offline_open_host,
	// open_join: a solo door has no join half — transport_join asserts.
	// pump/close/link/address: nothing to service or fold; the peer is inert
	// (installing the next door's real peer replaces it, like ENet's).
}

@(private = "file")
offline_open_host :: proc(wire: ^Session_Wire, at: Endpoint, name: string, token: u64, dedicated: bool) -> bool {
	_ = at
	mp := gd.node_get_multiplayer(wire.node)
	if cast(rawptr)mp == nil {
		return false
	}
	gd.multiplayer_api_set_multiplayer_peer(mp, gd.new_offline_multiplayer_peer())
	ksess.session_host_start(wire.ses, name, token, dedicated)
	return true
}

// ---- WebRTC ----------------------------------------------------------------

WEBRTC := Transport {
	name       = "webrtc",
	rendezvous = .Web_Room,
	open_host  = web_open_host,
	open_join  = web_open_join,
	pump       = web_poll, // the signaling socket is ours; the data channel is the engine's
	close      = web_close,
	// link: the browser's RTCPeerConnection stats are not plumbed through the
	// engine's peer — nil, so the netgraph blanks its link row instead of
	// showing an ENet-shaped zero.
	// address: a room code is the run's rendezvous, not a peer's — the torch's
	// .Web_Room arm carries the reservation the HOST minted, and needs no
	// per-peer answer. (succession_torch's web arm never calls this.)
}

@(private = "file")
web_open_host :: proc(wire: ^Session_Wire, at: Endpoint, name: string, token: u64, dedicated: bool) -> bool {
	if !gd.webrtc_host(wire.node, at.addr, at.room) {
		return false
	}
	// A browser tab makes a poor always-on box; `dedicated` is accepted (the
	// door is uniform) and passed through, so a relay-hosted headless build
	// gets the same infrastructure seat a native one would.
	ksess.session_host_start(wire.ses, name, token, dedicated)
	return true
}

@(private = "file")
web_open_join :: proc(wire: ^Session_Wire, at: Endpoint, name: string, token: u64, spectate: bool) -> bool {
	if !gd.webrtc_join(wire.node, at.addr, at.room) {
		return false
	}
	ksess.session_client_start(wire.ses, token, name, spectate)
	return true
}
