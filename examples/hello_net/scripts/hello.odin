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
import kui "godot:kit/ui"

DEFAULT_PORT :: 4242
SPEED :: f32(160)

HelloNet :: struct {
	owner:   gd.Node2d,
	ses:     ksess.Session, // identity, roster, replication — the session
	comms:   kcomms.Comms,  // chat + system lines (the stock lobby uses it)
	boot:    kboot.Boot,    // the stock stack: lobby UI, transport, factory
	// (no `running`/`started` pair: kboot.boot_phase answers both, derived from
	// the session — see hello_net_process. The bools drifted, too: `running`
	// never went back to false after a failed join, so the Host button stayed
	// dead for the rest of the run.)

	// THE declaration: this exported scene bodies a replicated entity. The
	// tag mints the wire id, the factory, typed player_spawn(), the census
	// (my_player / player_of / player_ids), and the acid probes.
	player_scene: ^gd.Resource `gd:"entity=Player:1"`,

	me: ^Player, // my avatar (set by the census hook in player.odin)

	// JOIN CODES (optional): with HELLO_RELAY set, hosting registers the ENet
	// port under a minted code and a friend joins with the CODE instead of an
	// address — the relay is a phonebook, the game stays plain ENet. The boot
	// doors (boot_host_coded / boot_join_code) run the whole rendezvous.
	minted: bool, // the code receipt printed once
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
		// (Options.methods defaulted: the on_host/on_join/... procs below are
		// the standard eight names, and scriptgen still validates they exist.)
	})
	// The factory, written by nobody — the entity tag above IS the table.
	kboot.boot_entities(&self.boot, self, hello_net_entity_kinds[:])

	// With a relay configured, the lobby grows its join-code field — a human
	// types a friend's code and presses Join (see on_join).
	if gd.env_string("HELLO_RELAY", "") != "" {
		kui.lobby_show_code(&self.boot.ui, true)
	}

	// Headless acids pick a role from the env; humans click the lobby.
	switch gd.env_string("HELLO_ROLE", "") {
	case "host":
		hello_net_on_host(self)
	case "join":
		hello_net_on_join(self)
	case "code":
		// Join by CODE: the door asks the relay where the host lives, then
		// it's a normal ENet join — boot_pump completes it when the
		// phonebook answers.
		relay := gd.env_string("HELLO_RELAY", "")
		code := gd.env_string("HELLO_CODE", "")
		if relay != "" && code != "" {
			gd.print_str(fmt.tprintf("HELLO_CODE_JOIN code=%s", code))
			kboot.boot_join_code(&self.boot, fmt.ctprintf("%s", relay), code, kboot.boot_token(&self.boot), kboot.boot_name(&self.boot, "player"))
		}
	}
}

hello_net_process :: proc(self: ^HelloNet, delta: f64) {
	// THE LIFECYCLE, read not kept. `.Menu` is "no seat and none coming" — the
	// old `running` bool, except this one is derived from the session, so it
	// goes back to false when a join fails instead of latching forever. Read
	// BEFORE the pump on purpose: boot_pump is the only place the phase RISES,
	// so `was` versus the phase after it is the rising edge the `started` bool
	// existed to detect (see the swap at the bottom).
	was := kboot.boot_phase(&self.boot)
	if was == .Menu {return}
	events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())
	// The minted code is a FACT to poll, not a callback: show it when it lands
	// (the stock lobby status already carries it; this is the headless receipt).
	if !self.minted {
		if room := kboot.boot_room_code(&self.boot); room != "" {
			self.minted = true
			gd.print_str(fmt.tprintf("HELLO_CODE room=%s", room))
		}
	}
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

	// The world ARRIVED this frame — the once-only receipt. boot_phase is a
	// LEVEL and the halves below fire per spawn, so the edge is computed here,
	// from two reads of the level, and needs no bool on this struct.
	if was != .Playing && kboot.boot_phase(&self.boot) == .Playing {
		gd.print_str("HELLO_STARTED")
	}
}

// ---- the doors (wired to the stock lobby's buttons by name) ----------------

@(gd_method)
hello_net_on_host :: proc(self: ^HelloNet) {
	if kboot.boot_phase(&self.boot) != .Menu {return} // a door is only a door from the menu
	port := kboot.boot_port(&self.boot, DEFAULT_PORT)
	// With a relay configured, host WITH a join code — the coded door is
	// boot_host plus "register the port under a code the status line shows".
	ok: bool
	if relay := gd.env_string("HELLO_RELAY", ""); relay != "" {
		ok = kboot.boot_host_coded(&self.boot, fmt.ctprintf("%s", relay), port, kboot.boot_name(&self.boot, "player"))
	} else {
		ok = kboot.boot_host(&self.boot, port, kboot.boot_name(&self.boot, "player"))
	}
	if !ok {return}
	hello_net_on_start(self) // a lone host starts at once; joiners drop in
}

@(gd_method)
hello_net_on_join :: proc(self: ^HelloNet) {
	if kboot.boot_phase(&self.boot) != .Menu {return}
	// A code in the lobby's field joins THROUGH it; empty joins by address.
	if code := kui.lobby_code(&self.boot.ui); code != "" {
		if relay := gd.env_string("HELLO_RELAY", ""); relay != "" {
			kboot.boot_join_code(&self.boot, fmt.ctprintf("%s", relay), code, kboot.boot_token(&self.boot), kboot.boot_name(&self.boot, "player"))
		}
		return
	}
	kboot.boot_join(&self.boot, "127.0.0.1", kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_token(&self.boot), kboot.boot_name(&self.boot, "player"))
}

@(gd_method)
hello_net_on_start :: proc(self: ^HelloNet) {
	// .Playing is "the world already reached this screen" — the old `started`
	// bool, minus the frame of lag it carried (it flipped on the drained event,
	// this flips in the same drain).
	if !self.ses.is_host || kboot.boot_phase(&self.boot) == .Playing {return}
	for _, p in self.ses.players {
		if p.connected {spawn_player(self, p.id)}
	}
	ksess.session_start_replicating(&self.ses) // go live; joiners catch up behind their WELCOME
}

@(gd_method)
hello_net_on_chat :: proc(self: ^HelloNet, text: gd.String) {
	if kboot.boot_phase(&self.boot) != .Menu {kboot.boot_chat(&self.boot, text)}
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

@(gd_half)
hello_net_welcomed :: proc(self: ^HelloNet, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("HELLO_SEATED me=%d", u64(me)))
}

// The join's authority consequence: field a drop-in square for the arrival.
@(gd_half)
hello_net_player_joined_then :: proc(self: ^HelloNet, id: knet.Player_Id, rejoin: bool) {
	if kboot.boot_phase(&self.boot) == .Playing && !rejoin {
		spawn_player(self, id)
	}
}

// The world reached this peer: the lobby gives way to the game. A LEVEL applied
// per spawn, not a latch — `started` used to be one bool doing double duty
// (level AND rising edge), and the edge is the only half that needed keeping:
// it rides boot_phase in process(), where the receipt prints exactly once.
@(gd_half)
hello_net_entity_spawned :: proc(self: ^HelloNet, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = type; _ = id; _ = owner
	gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
}
