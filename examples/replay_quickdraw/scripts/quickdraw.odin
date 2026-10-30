//gd:extends Node2D
//gd:class ReplayQuickdraw
package replay_quickdraw

import "core:fmt"
import "core:math"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/duel"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"
import flow "../shared/feedback"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

ReplayQuickdraw :: struct {
	owner: gd.Node2d,
	ui: [1]Quickdraw_UI,
	comms: co.Comms,
	diagnostics: dg.Diagnostics,
	views_ready, keyboard_captured, name_submitted: bool,
	display_name: lb.Name,
	name_sequence: u64,
	identity: net.Token,
	name_profile: storagegd.Name_Profile,
	profile_enabled,profile_name_loaded,profile_identity_ready: bool,
	browser_identity:storagegd.Browser_Identity,
	browser_launch:string,
	browser_save:[1]Quickdraw_Browser_Save,
	online:Quickdraw_Online,
	saved_tick,saved_hash,restored_tick,restored_hash:u64,
	restored_exact:bool,
	status: gd.Label `gd:"onready=Status"`,
	session: ^rgd.Session(game.World, game.Controls, game.Action, game.Event, game.SEATS),
	standalone: rgd.Session(game.World, game.Controls, game.Action, game.Event, game.SEATS),
	room: rgd.Room(game.World, game.Controls, game.Action, game.Event, game.SEATS),
	gunners, drones, bullets, rings: scenegd.Nodes2,
	feedback: [1]flow.Feedback,
	drawn: [game.SEATS]game.Player,
	beam_time: [game.SEATS]f64,
	beam_aim: [game.SEATS]u16,
	beam_id: [game.SEATS]r.Event_Id,
	ready: bool,
	bot: string,
	started, last_receipt, painted_epoch: u64,
	local_shots, watched_shots, local_lobs, speculative_lobs: u32,
	last_lob: u64,
	lob_held: bool,
	lob_waiting: bool,
	lob_requested_ms, lob_pending_key, lob_visible_max_ms: u64,
	lob_visible_count: u32,
	stopping: bool,
	seated: bool,
	view_epoch: u64,
	manual: bool,
	manual_move: [2]i8,
	manual_drone: i8,
	manual_buttons: u8,
	manual_target: u16,
	recovery_probe: Recovery_Probe,
}

replay_quickdraw_ready :: proc(self: ^ReplayQuickdraw) {
 self.session=&self.standalone;controls()
 self.views_ready=scenegd.nodes_load(&self.gunners,self.owner,"res://views/gunner.tscn",game.SEATS) &&
                  scenegd.nodes_load(&self.drones,self.owner,"res://views/drone.tscn",game.SEATS) &&
                  scenegd.nodes_load(&self.bullets,self.owner,"res://views/bullet.tscn",64) &&
                  scenegd.nodes_load(&self.rings,self.owner,"res://views/landing_ring.tscn",flow.RING_LIMIT) && flow.init(&self.feedback[0])
 if !self.views_ready || !co.init(&self.comms) || !dg.init(&self.diagnostics) {gd.print_str("REPLAY_QUICKDRAW_FAIL views/social");return}
 self.bot=strings.clone(quickdraw_param("RQ_BOT",""));self.identity=storagegd.session_token(quickdraw_param("RQ_TOKEN",""))
 ui_ready(self);online_ready(self)
 role:=quickdraw_param("RQ_ROLE","")
 // Existing coordinated launchers select the Room through these credentials.
 if role=="" && quickdraw_int("RQ_COORD_PORT",0)!=0 && quickdraw_int("RQ_AUTO",1)!=0 {role="solo"}
 if role!="" {when gd.IS_WEB {self.browser_launch=strings.clone(role)} else {connect_duel(self,role,false,quickdraw_int("RQ_RESUME",0)==1)}}
 gd.print_str("REPLAY_QUICKDRAW_UI_READY")
}

connect_duel :: proc(self:^ReplayQuickdraw,role:string,manual_start:bool,resume:bool=false) {
 if self.ready || !self.views_ready || (self.online.party.active && !self.online.launch) {return}
 if !profile_available(self) {ui_notice(self,self.name_profile.failed ? "Could not load the saved name. Existing profile data was kept." : "Loading the player profile…");return}
 when gd.IS_WEB {if !self.online.launch && role!="solo" {ui_notice(self,"Browser multiplayer uses a configured party service.");return}}
 opts:=rgd.SESSION_OPTIONS
 switch role {case "solo":opts.role=.Solo;case "host":opts.role=.Host;case "server":opts.role=.Server;case "client":opts.role=.Client;case "observer":opts.role=.Observer;case:return}
 port:=int(gd.range_get_value(self.ui[0].port));if port<1 || port>65535 {ui_notice(self,"Use a port from 1 to 65535.");return}
 text:=gd.line_edit_get_text(self.ui[0].name);name,valid:=lb.name(gd.gd_string_to_odin(text));gd.free_string(text)
 if !valid {ui_notice(self,"Enter a display name.");return}
 token,profile_ok:=profile_connect(self,name);if !profile_ok {return};self.identity=token
 self.display_name=name;gd.set_string(self.ui[0].name,"text",fmt.ctprintf("%s",lb.text(&name)))
 address:=gd.line_edit_get_text(self.ui[0].address);defer gd.free_string(address)
 host:=strings.trim_space(gd.gd_string_to_odin(address))
 if (opts.role==.Client || opts.role==.Observer) && host=="" {ui_notice(self,"Enter a host address.");return}
 opts.address=fmt.ctprintf("%s",host);opts.port=u16(port);opts.token=self.online.launch ? self.online.party.grant.token : self.identity
 opts.network.hz,opts.network.lead,opts.network.snapshot_every,opts.network.watch_delay=60,4,3,6
 opts.network.content=game.CONTENT;opts.remote_observed=true
 opts.discover_epoch=quickdraw_int("RQ_COORD_PORT",0)==0 && !self.online.launch
 opts.latency_ms=u32(quickdraw_int("RQ_LATENCY",0));opts.jitter_ms=u32(quickdraw_int("RQ_JITTER",0))
 opts.loss_permyriad=u32(quickdraw_int("RQ_LOSS",0));opts.duplicate_permyriad=u32(quickdraw_int("RQ_DUPLICATE",0))
 if !rgd.session_comms_enable(&opts) || !debuggd.session_diagnostics_enable(&opts) {ui_notice(self,"Could not configure social channels.");return}
 initial:=game.initial(quickdraw_int("RQ_NOREWIND",0)==0,opts.role==.Server,u8(clamp(quickdraw_int("RQ_GOLD",0),0,255)),manual_start)
 err:=resume ? resume_duel(self,opts) : open_session(self,initial,opts)
 if err!=.None {if !resume {ui_notice(self,fmt.tprintf("Connection failed: %v",err))};gd.print_str(fmt.tprintf("RQ_CONNECT_FAILED %v",err));return}
 self.ready=true;self.started=gd.time_get_ticks_msec(gd.singleton_time())
 gd.control_release_focus(self.ui[0].name);gd.control_release_focus(self.ui[0].address);gd.control_release_focus(gd.spin_box_get_line_edit(self.ui[0].port))
 ui_notice(self,resume ? "Saved duel restored." : opts.role==.Client || opts.role==.Observer ? "Joining the duel…" : "Duel open — invite players, then start.")
 gd.print_str("REPLAY_QUICKDRAW_READY")
}

controls :: proc() {
	if gd.has_action("rq_left") {return}
	names := [9]cstring{"rq_left", "rq_right", "rq_up", "rq_down", "rq_buy", "rq_drone_left", "rq_drone_right", "rq_drone_up", "rq_drone_down"}
	keys := [9]u8{'A', 'D', 'W', 'S', 'B', 'J', 'L', 'I', 'K'}
	for name, i in names {inputgd.bind_key(name, gd.Key(keys[i]))}
	inputgd.bind_key("rq_dash", .Space)
	inputgd.bind_mouse("rq_fire", .Left); inputgd.bind_mouse("rq_lob", .Right)
}

sample :: proc(self: ^ReplayQuickdraw, tick: u64, seat: u16) -> game.Controls {
	c: game.Controls
	if self.stopping || seat == 0 || self.keyboard_captured {return c}
	if self.manual {
		c = {move = self.manual_move, drone = {self.manual_drone, 0}, buttons = self.manual_buttons}
		if self.manual_target > 0 && self.manual_target <= game.SEATS {
			d := self.drawn[self.manual_target - 1].position - self.drawn[seat - 1].position
			c.aim = game.aim(math.atan2(d[1], d[0]))
		}
		return c
	}
	if self.bot != "" {
		c.drone[0] = (tick / 96) % 2 == 0 ? 1 : -1
		if self.bot == "strafer" {c.move[1] = (tick / 72) % 2 == 0 ? 1 : -1} else if self.bot == "orbit" {
			c.move = {math.cos(f32(tick) * 0.021) > 0 ? i8(1) : i8(-1), math.sin(f32(tick) * 0.021) > 0 ? i8(1) : i8(-1)}
			if tick % 120 == 0 {c.buttons |= game.DASH}
		}
		if self.bot != "strafer" {
			if tick % 90 == 0 && self.bot != "lobber" {c.buttons |= game.FIRE}
			if tick % 54 == 0 && quickdraw_int("RQ_NOLOB", 0) == 0 {c.buttons |= game.LOB}
		}
		origin := self.drawn[seat - 1].position
		best := f32(1e30)
		for player, i in self.drawn {
			if i + 1 == int(seat) || !player.connected || player.hp <= 0 {continue}
			d := player.position - origin
			n := d[0] * d[0] + d[1] * d[1]
			if n < best {best = n; c.aim = game.aim(math.atan2(d[1], d[0]))}
		}
		return c
	}
	if gd.is_action_pressed("rq_left") {c.move[0] -= 1}; if gd.is_action_pressed("rq_right") {c.move[0] += 1}
	if gd.is_action_pressed("rq_up") {c.move[1] -= 1}; if gd.is_action_pressed("rq_down") {c.move[1] += 1}
	if gd.is_action_pressed("rq_drone_left") {c.drone[0] -= 1}; if gd.is_action_pressed("rq_drone_right") {c.drone[0] += 1}
	if gd.is_action_pressed("rq_drone_up") {c.drone[1] -= 1}; if gd.is_action_pressed("rq_drone_down") {c.drone[1] += 1}
	if gd.is_action_pressed("rq_fire") {c.buttons |= game.FIRE}; if gd.is_action_pressed("rq_dash") {c.buttons |= game.DASH}; if gd.is_action_pressed("rq_lob") {c.buttons |= game.LOB}
	mouse := gd.canvas_item_get_local_mouse_position(self.owner)
	d := mouse - self.drawn[seat - 1].position
	c.aim = game.aim(math.atan2(d[1], d[0]))
	return c
}

replay_quickdraw_process :: proc(self: ^ReplayQuickdraw, dt: f64) {
	if self.ui[0].lobby==nil {return}
	profile_frame(self);browser_save_frame(self);browser_launch_frame(self);online_frame(self)
	self.keyboard_captured=ui_input(self)
	defer ui_frame(self)
	if !self.ready {return}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	frame, available := rgd.session_state(self.session)
	seat := rgd.session_seat(self.session)
	if available && !self.seated {self.seated = true; gd.print_str(fmt.tprintf("RQ_SEATED seat=%d", seat))}
	if available && frame.state.started && seat != 0 && !self.stopping && !self.keyboard_captured {
		player := frame.state.players[seat - 1]
		if gd.is_action_just_pressed("rq_buy") || (self.bot != "" && !player.boots && player.gold > 0) {
			issue(self, game.Action{item = 1})
		}
	}
	control := sample(self, frame.tick + 1, seat)
	lob := control.buttons & game.LOB != 0
	if lob && available && seat > 0 && frame.state.players[seat - 1].hp > 0 && frame.state.players[seat - 1].lob_cd == 0 && !self.lob_waiting {
		self.lob_requested_ms, self.lob_waiting = now, true
	}
	if !lob {self.lob_waiting = false}
	self.lob_held = lob
	err := self.room.ready ? rgd.room_frame(&self.room, dt, control) : rgd.session_frame(self.session, dt, control)
	if err != .None {gd.print_str(fmt.tprintf("REPLAY_QUICKDRAW_FAIL frame %v", err)); return}
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	reset := epoch != self.view_epoch || (!self.session.authority && self.painted_epoch != self.session.client.view_reset)
	if reset {
		self.view_epoch = epoch
		self.name_submitted=false;self.name_sequence=0;self.last_receipt=0
		scenegd.nodes_clear(&self.gunners); scenegd.nodes_clear(&self.drones); scenegd.nodes_clear(&self.bullets)
		self.beam_time, self.beam_id, self.last_lob, self.lob_pending_key, self.lob_waiting = {}, {}, 0, 0, false
	}
	if !self.session.authority && self.painted_epoch != self.session.client.view_reset {
		self.painted_epoch = self.session.client.view_reset
		gd.print_str(fmt.tprintf("RQ_VIEW_RESET count=%d baseline=%d", self.painted_epoch, self.session.client.baseline))
	}
	feedback_prepare(self,dt)
	changes: [320]v.Change(net.Net_Event(game.Event))
	n := rgd.session_changes(self.session, changes[:])
	for change in changes[:n] {
  result:=change.occurrence.value
  if result.kind==.Action_Result && result.seat==seat && (change.kind==.Confirm || change.confirmed) && result.sequence>self.last_receipt {
   self.last_receipt=result.sequence
   if result.sequence==self.name_sequence && !result.applied {self.name_submitted=false}
  }
		if change.occurrence.value.kind != .Gameplay {continue}
		event := change.occurrence.value.value
		flow.change(&self.feedback[0],v.Change(game.Event){kind=change.kind,occurrence={change.occurrence.id,event},previous=change.previous.value,confirmed=change.confirmed})
		if event.kind == .Shot && event.seat > 0 {
			if change.kind == .Cancel {
				if self.beam_id[event.seat - 1] == change.occurrence.id {self.beam_time[event.seat - 1] = 0}
				continue
			}
			if change.occurrence.id.epoch != epoch {continue}
			if change.kind == .Update && self.beam_id[event.seat - 1] == change.occurrence.id {self.beam_aim[event.seat - 1] = event.aim}
			if change.kind != .Begin {continue}
			self.beam_time[event.seat - 1], self.beam_aim[event.seat - 1] = 0.09, event.aim
			self.beam_id[event.seat - 1] = change.occurrence.id
			if u16(event.seat) == seat {self.local_shots += 1} else {self.watched_shots += 1}
			if !self.session.authority {gd.print_str(fmt.tprintf("RQ_SHOT_EFFECT from=%d tick=%d local=%v", event.seat, change.occurrence.id.tick, u16(event.seat) == seat))}
			if self.session.authority {gd.print_str(fmt.tprintf("RQ_SHOT seat=%d tick=%d judged=%d status=%v", event.seat, change.occurrence.id.tick, event.judged_tick, event.query))}
		}
		if event.kind == .Hit && change.kind == .Begin && self.session.authority {gd.print_str(fmt.tprintf("RQ_HIT by=%d on=%d", event.seat, event.target))}
		if event.kind == .Lobbed && change.kind == .Begin && u16(event.seat) == seat && event.key != self.last_lob {
			self.local_lobs += 1; self.last_lob = event.key
			self.lob_pending_key = event.key
			predicted, _ := rgd.session_state(self.session)
			if !self.session.authority && self.session.client.authority_frame.state.lobs < predicted.state.lobs {self.speculative_lobs += 1}
		}
	}
	for &ttl in self.beam_time {ttl = max(ttl - dt, 0)}
	paint(self)
	feedback_rings(self)
	social_frame(self)
	if self.room.ready && (self.manual || quickdraw_int("RQ_PROBE",0)==1) {observe_recovery(self)}
	if self.lob_pending_key != 0 {
		if _, exists := scenegd.nodes_get(&self.bullets, self.lob_pending_key); exists {
			self.lob_visible_count += 1
			self.lob_visible_max_ms = max(self.lob_visible_max_ms, gd.time_get_ticks_msec(gd.singleton_time()) - self.lob_requested_ms)
			self.lob_pending_key = 0
			self.lob_waiting = false
		}
	}
	seconds := quickdraw_int("RQ_TEST_SECONDS", 0)
	if seconds > 0 {
		if now - self.started > u64(seconds) * 1000 {self.stopping = true}
		// Drain the 70-tick projectile lifetime and network/watch delay before
		// taking final receipts. The authority stays available for both clients.
		if now - self.started > u64(seconds + (self.session.authority ? 5 : 3)) * 1000 {
			truth, _ := rgd.session_state(self.session)
			if !self.session.authority {truth = self.session.client.authority_frame}
			gd.print_str(fmt.tprintf("RQ_RESULT authority=%v shots=%d hits=%d lobs=%d lands=%d buys=%d invalid=%d local=%d watched=%d predicted_lobs=%d", self.session.authority,
			                        truth.state.shots, truth.state.hits, truth.state.lobs, truth.state.lands, truth.state.buys, truth.state.expired_queries,
			                        self.local_shots, self.watched_shots, self.speculative_lobs))
			stats := self.session.authority ? self.session.server.stats : self.session.client.stats
			gd.print_str(fmt.tprintf("RQ_METRICS visible_lobs=%d lob_visible_max_ms=%d corrections=%d replay_ticks=%d rx_bytes=%d tx_bytes=%d rejected_views=%d expired_views=%d resyncs=%d stalls=%d",
			                        self.lob_visible_count, self.lob_visible_max_ms, stats.corrections, stats.replayed_ticks,
			                        stats.rx_bytes, stats.tx_bytes, stats.rejected_views, stats.expired_views, stats.resyncs, stats.stalls))
			gd.print_str("REPLAY_QUICKDRAW_PROCESS_OK")
			gd.scene_tree_quit(gd.get_tree(self.owner), 0)
		}
	}
}

paint :: proc(self: ^ReplayQuickdraw) {
	frame, ok := rgd.session_state(self.session)
	if !ok {gd.set_text(cast(gd.Object)self.status, "Riding into town…"); return}
	seat := rgd.session_seat(self.session)
	if !frame.state.started {
		scenegd.nodes_clear(&self.gunners);scenegd.nodes_clear(&self.drones);scenegd.nodes_clear(&self.bullets)
		gd.set_string(self.status,"text","Waiting for the match leader to start.");return
	}
	w := frame.state
	observed := w
	next_observed := w
	observed_alpha := f32(0)
	watched_available:=self.session.authority
	self.drawn = w.players
	if !self.session.authority {
		a, b, alpha, available := net.client_present(&self.session.client)
		if available {
			watched_available=true
			observed = alpha >= 1 ? b.state : a.state
			next_observed, observed_alpha = b.state, alpha
			for &player, i in self.drawn {
				if i + 1 == int(seat) {continue}
				old, next := a.state.players[i], b.state.players[i]
				player = alpha >= 1 ? next : old
				if old.life == next.life && old.connected == next.connected {
					player.position = old.position + (next.position - old.position) * alpha
					player.drone = old.drone + (next.drone - old.drone) * alpha
					difference := game.angle(next.aim) - game.angle(old.aim)
					for difference > math.PI {difference -= 2 * math.PI}; for difference < -math.PI {difference += 2 * math.PI}
					player.aim = game.aim(game.angle(old.aim) + difference * alpha)
				}
			}
		}
	}
	instances: [64]scenegd.Instance2
	bullet_colors:[64]gd.Color
	n := 0
	colors := [4]gd.Color{{0.35, 0.65, 1, 1}, {1, 0.62, 0.2, 1}, {0.5, 0.9, 0.4, 1}, {0.9, 0.45, 0.9, 1}}
	for player, i in self.drawn {
		if !player.connected {continue}
		instances[n] = {key = u64(i + 1), pose = {position = player.position}, scale = {1, 1}, color = {1,1,1,1}}; n += 1
	}
	scenegd.nodes_present(&self.gunners, instances[:n])
	authority,authority_ok:=rgd.session_authority_state(self.session)
	for player, i in self.drawn {
		health:=player
		if i+1==int(seat) && authority_ok {health=authority.state.players[i]}
		if self.session.authority || (i+1==int(seat) && authority_ok) || (i+1!=int(seat) && watched_available) {
			flow.health(&self.feedback[0],i,health.life,health.hp,health.connected)
		}
		if node, present := scenegd.nodes_get(&self.gunners, u64(i + 1)); present {
			gd.node2d_set_rotation(cast(gd.Node2d)gd.get_node(node, "Gun"), f64(game.angle(player.aim)))
			beam := gd.get_node(node, "Beam")
			gd.set_bool(cast(gd.Object)beam, "visible", self.beam_time[i] > 0)
			gd.node2d_set_rotation(cast(gd.Node2d)beam, f64(game.angle(self.beam_aim[i])))
			gd.node2d_set_scale(cast(gd.Node2d)beam, {game.wall_limit(player.position, game.direction(self.beam_aim[i])) / 100, 1})
		}
	}
	n = 0
	for player, i in self.drawn {if player.connected {instances[n] = {key = u64(i + 1), pose = {position = player.drone}, scale = {1, 1}, color = {1,1,1,1}}; n += 1}}
	scenegd.nodes_present(&self.drones, instances[:n])
	for player,i in self.drawn {if node,present:=scenegd.nodes_get(&self.drones,u64(i+1));present {gd.canvas_item_set_self_modulate(cast(gd.Canvas_Item)gd.get_node(node,"Skin"),colors[i])}}
	n = 0
	for bullet, i in w.bullets.values {if w.bullets.alive[i] && (self.session.authority || int(bullet.owner) == int(seat)) {
		bullet_colors[n]=colors[bullet.owner-1]
		instances[n] = {key = bullet.key, pose = {position = bullet.position}, scale = {1, 1}, color = {1,1,1,1}}; n += 1
	}}
	if !self.session.authority {for bullet, i in observed.bullets.values {if observed.bullets.alive[i] && int(bullet.owner) != int(seat) && n < len(instances) {
		position := bullet.position
		for next, j in next_observed.bullets.values {if next_observed.bullets.alive[j] && next.key == bullet.key {position += (next.position - position) * observed_alpha; break}}
		bullet_colors[n]=colors[bullet.owner-1]
		instances[n] = {key = bullet.key, pose = {position = position}, scale = {1, 1}, color = {1,1,1,1}}; n += 1
	}}}
	scenegd.nodes_present(&self.bullets, instances[:n])
	for instance,i in instances[:n] {
		if node,present:=scenegd.nodes_get(&self.bullets,instance.key);present {gd.canvas_item_set_self_modulate(cast(gd.Canvas_Item)gd.get_node(node,"Skin"),bullet_colors[i])}
	}
	if seat != 0 {player := w.players[seat - 1]; gd.set_string(cast(gd.Object)self.status, "text", fmt.ctprintf("HP %d   Gold %d   Kills %d   Deaths %d   %s", player.hp, player.gold, player.kills, player.deaths, player.boots ? "BOOTS" : ""))}
	if seat==0 {gd.set_string(self.status,"text","Watching the duel · Enter chat · Tab scores")}
	if self.room.ready && (self.session.fenced || self.room.phase == .Freezing || self.room.phase == .Releasing || self.room.phase == .Claiming || self.room.phase == .Recovering) {
		gd.set_text(cast(gd.Object)self.status, "Host changing… reconnecting to the match.")
	}
}

replay_quickdraw_exit_tree :: proc(self: ^ReplayQuickdraw) {
	flow.destroy(&self.feedback[0]);scenegd.nodes_destroy(&self.rings)
	co.destroy(&self.comms);dg.destroy(&self.diagnostics);storagegd.name_profile_close(&self.name_profile)
	scenegd.nodes_destroy(&self.gunners); scenegd.nodes_destroy(&self.drones); scenegd.nodes_destroy(&self.bullets)
	if self.room.ready {rgd.room_close(&self.room)} else if self.session != nil {rgd.session_close(self.session)}
	online_close(self);browser_save_close(self);storagegd.browser_identity_close(&self.browser_identity);delete(self.browser_launch)
	delete(self.bot)
}
