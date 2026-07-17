//gd:extends Node2D
//gd:class HelloNet
package hello_net

// ----------------------------------------------------------------------------
// HELLO, MULTIPLAYER — the smallest complete kit game: two windows, one
// square each, moving with the arrow keys on both screens. This file plus
// player.odin is the WHOLE game; docs/kit/quickstart.md walks it line by
// line. Run it:
//
//   bash build/build_scripts.sh examples/hello_net
//   $GODOT --path examples/hello_net &          # window 1: press Host
//   $GODOT --path examples/hello_net            # window 2: press Join
//
// What you do NOT see here is the point: no RPCs, no role branches, no
// spawn messages, no interpolation code. Declarations (the `gd:` tags, the
// entity tag, the Options) plus plain procs — the kit routes everything.
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"

DEFAULT_PORT :: 4242
SPEED :: f32(160)

HelloNet :: struct {
	owner:   gd.Node2d,
	ses:     ksess.Session, // identity, roster, replication — the session
	comms:   kcomms.Comms,  // chat + system lines (the stock lobby uses it)
	boot:    kboot.Boot,    // the stock stack: lobby UI, transport, factory
	running: bool,          // transport up (hosting or joining)
	started: bool,          // the world reached this peer

	// THE declaration: this exported scene bodies a replicated entity. The
	// tag mints the wire id, the factory, typed player_spawn(), the census
	// (my_player / player_of / player_ids), and the acid probes.
	player_scene: ^gd.Resource `gd:"export,resource=PackedScene,entity=Player:1"`,

	me: ^Player, // my avatar (set by the census hook in player.odin)
}

now_s :: knet.now_s

hello_net_ready :: proc(self: ^HelloNet) {
	// The stock stack: a lobby with Host/Join buttons, chat, a scoreboard,
	// the wire, and the four transport forwards — attached, not written.
	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "HELLO, MULTIPLAYER",
		status = "Host a room, or join one at localhost",
		legend = "Arrows move · Enter chat",
		env = "HELLO", // HELLO_PORT/_NAME/_TOKEN identity + the HELLO_LATENCY bad-link shim
		min_players = 1,
		methods = {"on_host", "on_join", "on_start", "on_chat", "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	// The factory, written by nobody — the entity tag above IS the table.
	kboot.boot_entities(&self.boot, self, hello_net_entity_kinds[:])

	// Headless acids pick a role from the env; humans click the lobby.
	switch gd.env_string("HELLO_ROLE", "") {
	case "host":
		hello_net_on_host(self)
	case "join":
		hello_net_on_join(self)
	}
}

hello_net_process :: proc(self: ^HelloNet, delta: f64) {
	if !self.running {return}
	events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())
	if self.me != nil {
		// Drive MY square. The x/y writes are all it takes: they are
		// owner-streamed fields, so every other screen glides this body.
		dx, dy: f32
		if gd.is_action_pressed("ui_right") {dx += 1}
		if gd.is_action_pressed("ui_left") {dx -= 1}
		if gd.is_action_pressed("ui_down") {dy += 1}
		if gd.is_action_pressed("ui_up") {dy -= 1}
		self.me.x = clamp(self.me.x + dx * SPEED * f32(delta), 8, 632)
		self.me.y = clamp(self.me.y + dy * SPEED * f32(delta), 8, 352)
	}
	// Reactions live in the name-paired halves below; the generated
	// hello_net_events holds the switch and every role gate.
	hello_net_events(self, events)
}

// ---- the doors (wired to the stock lobby's buttons by name) ----------------

@(gd_method)
hello_net_on_host :: proc(self: ^HelloNet) {
	if self.running {return}
	if !kboot.boot_host(&self.boot, kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_name(&self.boot, "player")) {return}
	self.running = true
	hello_net_on_start(self) // a lone host starts at once; joiners drop in
}

@(gd_method)
hello_net_on_join :: proc(self: ^HelloNet) {
	if self.running {return}
	if !kboot.boot_join(&self.boot, "127.0.0.1", kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_token(&self.boot), kboot.boot_name(&self.boot, "player")) {return}
	self.running = true
}

@(gd_method)
hello_net_on_start :: proc(self: ^HelloNet) {
	if !self.ses.is_host || self.started {return}
	for _, p in self.ses.players {
		if p.connected {spawn_player(self, p.id)}
	}
	ksess.session_start_replicating(&self.ses) // go live; joiners catch up behind their WELCOME
}

@(gd_method)
hello_net_on_chat :: proc(self: ^HelloNet, text: gd.String) {
	if self.running {kboot.boot_chat(&self.boot, text)}
}

// Host: one square per seat, fanned so nobody spawns inside anybody.
spawn_player :: proc(self: ^HelloNet, pid: knet.Player_Id) {
	if _, has := player_owned_by(&self.boot, pid); has {return}
	p, id := player_spawn(&self.boot, owner = pid) // typed, from the entity tag
	p.pid = u8(pid)
	p.x = 120 + f32(u64(pid) % 8) * 56
	p.y = 180
	kboot.boot_spawn_send(&self.boot, id)
}

// ---- session event halves (the generated dispatch holds the role gates) ----

hello_net_welcomed :: proc(self: ^HelloNet, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("HELLO_SEATED me=%d", u64(me)))
}

// The join's authority consequence: field a drop-in square for the arrival.
hello_net_player_joined_then :: proc(self: ^HelloNet, id: knet.Player_Id, rejoin: bool) {
	if self.started && !rejoin {
		spawn_player(self, id)
	}
}

// The world reached this peer: swap the lobby for the game, every role.
hello_net_entity_spawned :: proc(self: ^HelloNet, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = type; _ = id; _ = owner
	if !self.started {
		self.started = true
		gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
		gd.print_str("HELLO_STARTED")
	}
}
