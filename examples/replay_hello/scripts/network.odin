//gd:extends Node2D
//gd:class ReplayNetwork
package replay_hello

import "core:fmt"
import "core:crypto/sha2"
import gd "godot:godot"
import "godot:gdext"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/hello"

ReplayNetwork :: struct {
	owner: gd.Node2d,
	status: gd.Label `gd:"onready=Status"`,
	effect: gd.Node2d `gd:"onready=Flash"`,
	clock: r.Clock,
	buttons: r.Buttons,
	enet: rgd.Enet,
	delay: tr.Delay,
	wire: tr.Transport,
	server: net.Server(game.World, game.Controls, game.Action, game.Event, 2),
	client: net.Client(game.World, game.Controls, game.Action, game.Event, 2),
	views: rgd.Nodes2,
	hosting, spectating, dedicated, ready, failed: bool,
	begins, cancels, applied, rejected: u32,
	flash: f64,
}

replay_network_ready :: proc(self: ^ReplayNetwork) {
	role := gd.env_string("REPLAY_ROLE", "host")
	self.hosting = role == "host" || role == "server"
	self.dedicated = role == "server"
	self.spectating = role == "observer"
	port := gd.env_int("REPLAY_PORT", 49421)
	latency := gd.env_int("REPLAY_LATENCY", 0)
	jitter := gd.env_int("REPLAY_JITTER", 0)
	loss := gd.env_int("REPLAY_LOSS", 0)
	duplicate := gd.env_int("REPLAY_DUPLICATE", 0)
	if port < 1 || port > 65535 || latency < 0 || latency > 10000 || jitter < 0 || jitter > 10000 ||
	   loss < 0 || loss > 10000 || duplicate < 0 || duplicate > 10000 {replay_network_fail(self, "configuration"); return}
	ok := false
	if self.hosting {ok = rgd.enet_host(&self.enet, u16(port), 16)} else {
		address := gd.env_string("REPLAY_ADDRESS", "127.0.0.1")
		ok = rgd.enet_join(&self.enet, fmt.ctprintf("%s", address), u16(port))
	}
	if !ok {replay_network_fail(self, "transport"); return}
	self.wire = rgd.enet_transport(&self.enet)
	if latency > 0 || jitter > 0 || loss > 0 || duplicate > 0 {
		ok = tr.delay_init(&self.delay, self.wire, u32(latency))
		if !ok {replay_network_fail(self, "delay"); return}
		tr.delay_faults(&self.delay, u32(jitter), u32(loss), u32(duplicate), 42)
		self.wire = tr.delay_transport(&self.delay)
	}
	cfg := net.DEFAULT_CONFIG
	cfg.content = 0x5245504c41594831 // Replay Hello gameplay/content revision 1
	err: net.Error
	if self.hosting {
		err = net.server_init(&self.server, r.Frame(game.World){}, game.network_model(), self.wire, cfg,
		                      local_seat = self.dedicated ? 0 : 1)
	} else {
		token := replay_network_token()
		err = net.client_init(&self.client, game.network_model(), self.wire, token, spectator = self.spectating, cfg = cfg)
	}
	if err != .None {replay_network_fail(self, fmt.tprintf("initialization %v", err)); return}
	if !rgd.nodes_load(&self.views, self.owner, "res://actor.tscn", game.CAPACITY) {replay_network_fail(self, "views"); return}
	r.clock_init(&self.clock, cfg.hz)
	self.ready = true
	if self.hosting {gd.print_str("REPLAY_NETWORK_HOST_READY")}
}

// Deterministic labels are only for repeatable tests. Normal launches use a
// fresh cryptographic token. Persistence across application launches is M4 work.
replay_network_token :: proc() -> net.Token {
	if label := gd.env_string("REPLAY_TOKEN", ""); label != "" {
		ctx: sha2.Context_256
		sha2.init_256(&ctx)
		sha2.update(&ctx, transmute([]u8)label)
		digest: [32]u8
		sha2.final(&ctx, digest[:])
		token: net.Token
		copy(token[:], digest[:16])
		return token
	}
	crypto := gd.new_crypto()
	gd.ref_counted_init_ref(crypto)
	bytes := gd.crypto_generate_random_bytes(crypto, 16)
	token: net.Token
	copy(token[:], gd.packed_byte_array_view(&bytes))
	gd.free_packed_byte_array(bytes)
	if gd.ref_counted_unreference(crypto) {gdext.object_destroy(crypto)}
	return token
}

replay_network_process :: proc(self: ^ReplayNetwork, dt: f64) {
	if !self.ready || self.failed {return}
	now := u64(gd.time_get_ticks_msec(gd.singleton_time()))
	if self.delay.packets != nil {tr.delay_time(&self.delay, now)}
	err := self.hosting ? net.server_pump(&self.server, now) : net.client_pump(&self.client, now)
	if err != .None && err != .Presentation {replay_network_fail(self, fmt.tprintf("pump %v", err)); return}
	r.buttons_set(&self.buttons, gd.is_action_pressed("ui_accept") ? 1 : 0)
	if gd.is_action_just_pressed("ui_accept") {self.buttons.pressed |= 1}
	if self.buttons.pressed & 1 != 0 {
		if self.hosting && !self.dedicated {_, err = net.server_issue(&self.server, game.Action{fire = true})}
		if !self.hosting && !self.spectating && self.client.phase == .Running {_, err = net.client_issue(&self.client, game.Action{fire = true})}
		if err == .None {r.buttons_consume(&self.buttons)}
	}
	scale := self.hosting ? f64(1) : self.client.clock_scale
	steps, _ := r.clock_add(&self.clock, dt * scale)
	for _ in 0 ..< steps {
		control: game.Controls
		if gd.is_action_pressed("ui_left") {control.move[0] -= 1}
		if gd.is_action_pressed("ui_right") {control.move[0] += 1}
		if gd.is_action_pressed("ui_up") {control.move[1] -= 1}
		if gd.is_action_pressed("ui_down") {control.move[1] += 1}
		if self.hosting {
			if !self.dedicated {net.server_local(&self.server, control)}
			err = net.server_step(&self.server)
			if err != .None {replay_network_fail(self, "server step"); return}
			events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(game.Event))
			n, _ := r.copy_events(&self.server.timeline, self.server.timeline.head, events[:])
			for event in events[:n] {
				if event.value.kind == .Gameplay {replay_network_effect(self, event.value.value)}
			}
		} else if !self.spectating && self.client.phase == .Running {
			err = net.client_step(&self.client, control)
			if err != .None && err != .Capacity && err != .Presentation {replay_network_fail(self, "client step"); return}
		}
		r.clock_consume(&self.clock)
	}
	if !self.hosting {
		changes: [128]v.Change(net.Net_Event(game.Event))
		for {
			n := v.drain(&self.client.journal, changes[:])
			if n == 0 {break}
			for change in changes[:n] {
				if change.occurrence.value.kind != .Gameplay {continue}
				switch change.kind {
				case .Begin: replay_network_effect(self, change.occurrence.value.value)
				case .Cancel: self.cancels += 1
				case .Update, .Confirm:
				}
			}
		}
		outcomes: [16]net.Action_Outcome
		n := net.client_outcomes(&self.client, outcomes[:])
		for outcome in outcomes[:n] {if outcome.applied {self.applied += 1} else {self.rejected += 1}}
	}
	self.flash = max(self.flash - dt, 0)
	gd.canvas_item_set_visible(self.effect, self.flash > 0)
	replay_network_paint(self)
}

replay_network_effect :: proc(self: ^ReplayNetwork, event: game.Event) {
	self.begins += 1
	self.flash = 0.12
	gd.node2d_set_position(self.effect, event.position)
}

replay_network_frame :: proc(self: ^ReplayNetwork) -> r.Frame(game.World) {
	if self.hosting {frame, _ := r.current(&self.server.timeline); return frame}
	frame, _ := r.current(&self.client.timeline)
	return frame
}

replay_network_paint :: proc(self: ^ReplayNetwork) {
	frame := replay_network_frame(self)
	if self.spectating {
		if a, _, _, ok := net.client_observed(&self.client); ok {frame = a}
	}
	instances: [game.CAPACITY]rgd.Instance2
	n := 0
	for actor, i in frame.state.actors.values {
		if !frame.state.actors.alive[i] {continue}
		instances[n] = {key = u64(frame.state.actors.generations[i]) << 32 | u64(i + 1),
			pose = {position = actor.body.position}, scale = actor.body.half_size / 8,
			color = actor.owner == 0 ? gd.Color{0.35, 0.85, 1, 1} : gd.Color{1, 0.62, 0.3, 1}}
		n += 1
	}
	assert(rgd.nodes_present(&self.views, instances[:n]))
	role := self.hosting ? "authority" : self.spectating ? "observer" : "predicted player"
	gd.set_string(self.status, "text", fmt.ctprintf("REPLAY / NETWORK    %s    tick %d\nArrows move   Space fires\nShots %d   effects %d   accepted %d", role, frame.tick, frame.state.shots, self.begins, self.applied))
}

replay_network_fail :: proc(self: ^ReplayNetwork, message: string) {
	self.failed = true
	gd.print_str(fmt.tprintf("REPLAY_NETWORK_FAIL %s", message))
}

replay_network_exit_tree :: proc(self: ^ReplayNetwork) {
	net.server_destroy(&self.server)
	net.client_destroy(&self.client)
	rgd.nodes_destroy(&self.views)
	tr.close(&self.wire)
}

@(gd_method)
replay_network_probe_running :: proc(self: ^ReplayNetwork) -> bool {
	return self.ready && !self.failed && (self.hosting || self.client.phase == .Running)
}
@(gd_method)
replay_network_probe_players :: proc(self: ^ReplayNetwork) -> gd.Int {
	frame := replay_network_frame(self)
	n := 0
	for actor, i in frame.state.actors.values {if frame.state.actors.alive[i] && actor.kind == .Player {n += 1}}
	return gd.Int(n)
}
@(gd_method)
replay_network_probe_x :: proc(self: ^ReplayNetwork) -> f64 {
	seat := self.hosting ? self.server.local_seat : self.client.seat
	if seat == 0 {return 0}
	frame := replay_network_frame(self)
	actor, ok := r.pool_get(&frame.state.actors, frame.state.players[seat - 1])
	return ok ? f64(actor.body.position[0]) : 0
}
@(gd_method)
replay_network_probe_shots :: proc(self: ^ReplayNetwork) -> gd.Int {return gd.Int(replay_network_frame(self).state.shots)}
@(gd_method)
replay_network_probe_begins :: proc(self: ^ReplayNetwork) -> gd.Int {return gd.Int(self.begins)}
@(gd_method)
replay_network_probe_applied :: proc(self: ^ReplayNetwork) -> gd.Int {return gd.Int(self.applied)}
@(gd_method)
replay_network_probe_rejected :: proc(self: ^ReplayNetwork) -> gd.Int {return gd.Int(self.rejected)}
@(gd_method)
replay_network_probe_corrections :: proc(self: ^ReplayNetwork) -> gd.Int {return gd.Int(self.client.stats.corrections)}
@(gd_method)
replay_network_probe_deltas :: proc(self: ^ReplayNetwork) -> gd.Int {
	return gd.Int(self.hosting ? self.server.stats.delta_snapshots : self.client.stats.delta_snapshots)
}
