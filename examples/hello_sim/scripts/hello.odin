//gd:extends Node2D
//gd:class HelloSim
package hello_sim

// ----------------------------------------------------------------------------
// HELLO, SERVER AUTHORITY — hello_net promoted to the sim lane, following
// docs/kit/sim.md's promotion checklist. The session half (lobby, doors,
// spawns, drop-in, chat) matches hello_net minus the optional join-code
// doors it has since grown, plus the `serve` door; the whole promotion is:
// the retag in player.odin, the @(gd_tick), the @(gd_sample) below, and
// TWO wiring lines in ready(). Clients are no longer trusted with positions;
// their own square still moves the instant a key goes down (prediction), and
// remote squares render watched (interpolated, a breath in the past).
//
//   bash build/build_scripts.sh examples/hello_sim
//   $GODOT --path examples/hello_sim &          # window 1: press Host
//   HELLO_LATENCY=120 $GODOT --path examples/hello_sim   # window 2: Join, feel it
//
// The authority can also run headless and avatarless:
//   HELLO_ROLE=serve $GODOT --headless --path examples/hello_sim
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"

DEFAULT_PORT :: 4243

HelloSim :: struct {
	owner:   gd.Node2d,
	ses:     ksess.Session,
	comms:   kcomms.Comms,
	boot:    kboot.Boot,
	lane:    ksim.Lane, // the sim lane: tick scheduling, prediction, reconcile
	running: bool,
	started: bool,

	player_scene: ^gd.Resource `gd:"entity=Player:1"`,

	me: ^Player,
}

now_s :: knet.now_s

hello_sim_ready :: proc(self: ^HelloSim) {
	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "HELLO, SERVER AUTHORITY",
		status = "Host a room, or join one at localhost",
		legend = "Arrows move · Enter chat",
		env = "HELLO",
		min_players = 1,
		// methods omitted = kboot.STANDARD_METHODS — the eight names above
		// were the list every game wrote anyway
	})
	kboot.boot_entities(&self.boot, self, hello_sim_entity_kinds[:])

	// The promotion's ENTIRE wiring (checklist step 7): the generated
	// lane_init carries the tick/sample declarations; the boot drives the
	// lane — tracking, possession, presentation — from here on.
	hello_sim_lane_init(self, &self.lane, &self.ses)
	kboot.boot_lane(&self.boot, &self.lane)

	switch gd.env_string("HELLO_ROLE", "") {
	case "host":
		hello_sim_on_host(self)
	case "join":
		hello_sim_on_join(self)
	case "serve":
		hello_sim_on_serve(self)
	}
}

hello_sim_process :: proc(self: ^HelloSim, delta: f64) {
	if !self.running {return}
	// The coop hello drove `me` right here, at frame rate. Promoted, the
	// device read lives in the @(gd_sample) below and the movement in
	// player_tick — the frame loop only pumps.
	events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())
	hello_sim_events(self, events)
}

// The one place that still touches hardware (checklist step 4): fill my
// input for tick T. The lane ships it, the server simulates it, my own
// screen predicts it this frame.
@(gd_sample)
hello_sample :: proc(self: ^HelloSim, tick: u64, input: ^Player_Input) {
	_ = tick
	input^ = {}
	if gd.is_action_pressed("ui_right") {input.move[0] += 1}
	if gd.is_action_pressed("ui_left") {input.move[0] -= 1}
	if gd.is_action_pressed("ui_down") {input.move[1] += 1}
	if gd.is_action_pressed("ui_up") {input.move[1] -= 1}
}

// ---- the doors (identical to hello_net, plus the dedicated one) ------------

@(gd_method)
hello_sim_on_host :: proc(self: ^HelloSim) {
	if self.running {return}
	if !kboot.boot_host(&self.boot, kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_name(&self.boot, "player")) {return}
	self.running = true
	hello_sim_on_start(self)
}

@(gd_method)
hello_sim_on_join :: proc(self: ^HelloSim) {
	if self.running {return}
	if !kboot.boot_join(&self.boot, "127.0.0.1", kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_token(&self.boot), kboot.boot_name(&self.boot, "player")) {return}
	self.running = true
}

// The dedicated authority: referees and simulates, fields no square, and
// never hands anyone the succession torch. This is "running the authority"
// for a competitive game — a headless process on a machine you trust.
hello_sim_on_serve :: proc(self: ^HelloSim) {
	if self.running {return}
	if !kboot.boot_serve(&self.boot, kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_name(&self.boot, "referee")) {return}
	self.running = true
	hello_sim_on_start(self)
}

@(gd_method)
hello_sim_on_start :: proc(self: ^HelloSim) {
	if !self.ses.is_host || self.started {return}
	for _, p in self.ses.players {
		if p.connected && !p.dedicated {spawn_player(self, p.id)}
	}
	ksess.session_start_replicating(&self.ses)
}

@(gd_method)
hello_sim_on_chat :: proc(self: ^HelloSim, text: gd.String) {
	if self.running {kboot.boot_chat(&self.boot, text)}
}

spawn_player :: proc(self: ^HelloSim, pid: knet.Player_Id) {
	if _, has := player_owned_by(&self.boot, pid); has {return}
	p, id := player_spawn(&self.boot, owner = pid)
	p.pid = u8(pid)
	p.x = 120 + f32(u64(pid) % 8) * 56
	p.y = 180
	kboot.boot_spawn_send(&self.boot, id)
}

// ---- session event halves (identical to hello_net) --------------------------

@(gd_half)
hello_sim_welcomed :: proc(self: ^HelloSim, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("HELLO_SEATED me=%d", u64(me)))
}

@(gd_half)
hello_sim_player_joined_then :: proc(self: ^HelloSim, id: knet.Player_Id, rejoin: bool) {
	if self.started && !rejoin {
		spawn_player(self, id)
	}
}

@(gd_half)
hello_sim_entity_spawned :: proc(self: ^HelloSim, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = type; _ = id; _ = owner
	if !self.started {
		self.started = true
		gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
		gd.print_str("HELLO_STARTED")
	}
}
