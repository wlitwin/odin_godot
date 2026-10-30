//gd:extends Node2D
//gd:class ReplayClaimball
package replay_claimball

import "core:fmt"
import "core:math"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/pitch"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"

ReplayClaimball :: struct {
	owner: gd.Node2d,
	ui:[1]Claimball_UI,
	comms:co.Comms,
	diagnostics:dg.Diagnostics,
	views_ready,keyboard_captured,name_submitted,profile_enabled:bool,
	display_name:lb.Name,
	name_sequence:u64,
	identity:net.Token,
	name_profile:rgd.Name_Profile,
	online:Claimball_Online,
	browser_identity:rgd.Browser_Identity,
	profile_identity_ready,profile_name_loaded:bool,
	browser_launch:string,
	browser_save:[1]Claimball_Browser_Save,
	status: gd.Label `gd:"onready=Status"`,
	standalone: rgd.Session(game.World, game.Controls, game.Action, game.Event, game.SEATS),
	session: ^rgd.Session(game.World, game.Controls, game.Action, game.Event, game.SEATS),
	room: rgd.Room(game.World,game.Controls,game.Action,game.Event,game.SEATS),
	recovery_probe:[1]Pitch_Recovery,
	view_epoch:u64,
	players, ball: rgd.Nodes2,
	smoothing: [game.SEATS + 1]v.Smoother2,
	ready, spiked, spike_visible, done: bool,
	spike_node_start, own_spike_seen: bool,
	bot: string,
	started_ms, done_ms, reset_seen, correction_seen: u64,
	spike_at_ms, spike_at_tick, spike_first_sequence, last_verdict: u64,
	spike_from: [2]f32,
	local_kicks, remote_kicks, speculative_kicks, spike_applied, spike_rejected: u32,
	local_canceled, remote_canceled: u32,
	correction_count: u64,
	correction_sum, correction_max: f64,
	flash_left: f64,
	flash_id: r.Event_Id,
	goal_seen: u16,
	ball_reset: u32,
	view_round, paint_round: u32,
	saved_tick,saved_hash,restored_tick,restored_hash:u64,
	restored_exact:bool,
	claim: v.Claim2,
	claim_max, watched_error_max: f32,
	fast_far_samples, watched_samples: u64,
	predicted_samples: u64,
	predicted_error_max: f32,
	predicted_members: u32,
	remote_kicks_while_claimed: u32,
	contest_stop_tick: u64,
	resync_seen: u64,
	stall_injected: bool,
}

replay_claimball_ready :: proc(self:^ReplayClaimball) {
 self.session=&self.standalone
 install_controls()
 self.views_ready=rgd.nodes_load(&self.players,self.owner,"res://views/kicker.tscn",game.SEATS) && rgd.nodes_load(&self.ball,self.owner,"res://views/ball.tscn",1)
 if !self.views_ready || !co.init(&self.comms) || !dg.init(&self.diagnostics) {gd.print_str("REPLAY_CLAIMBALL_FAIL views/social");return}
 self.bot=strings.clone(claimball_param("RCB_BOT",""));self.identity=rgd.session_token(claimball_param("RCB_TOKEN",""))
 if claimball_int("RCB_CONTEST",0)==1 {self.contest_stop_tick=1800}
 ui_ready(self);online_ready(self)
 role:=claimball_param("RCB_ROLE","");if role!="" {when gd.IS_WEB {self.browser_launch=strings.clone(role)} else {connect_pitch(self,role,false,claimball_int("RCB_RESUME",0)==1)}}
 gd.print_str("REPLAY_CLAIMBALL_UI_READY")
}
connect_pitch :: proc(self:^ReplayClaimball,role:string,manual:bool,resume:bool=false) {
 if self.ready || !self.views_ready || (self.online.party.active && !self.online.launch) {return}
 if !profile_available(self) {ui_notice(self,self.name_profile.failed ? "Could not load the saved name. Existing profile data was kept." : "Loading the player profile…");return}
 when gd.IS_WEB {if !self.online.launch && role!="solo" {ui_notice(self,"Browser multiplayer uses a configured party service.");return}}
 opts:=rgd.SESSION_OPTIONS
 switch role {case "solo":opts.role=.Solo;case "host":opts.role=.Host;case "client":opts.role=.Client;case "observer":opts.role=.Observer;case "server":opts.role=.Server;case:return}
 port:=int(gd.range_get_value(self.ui[0].port));if port<1 || port>65535 {ui_notice(self,"Use a port from 1 to 65535.");return}
 text:=gd.line_edit_get_text(self.ui[0].name);name,valid:=lb.name(gd.gd_string_to_odin(text));gd.free_string(text)
 if !valid {ui_notice(self,"Enter a display name.");return}
 token,profile_ok:=profile_connect(self,name);if !profile_ok {return};self.identity=token
 self.display_name=name
 address:=gd.line_edit_get_text(self.ui[0].address);defer gd.free_string(address);host:=strings.trim_space(gd.gd_string_to_odin(address))
 if (opts.role==.Client || opts.role==.Observer) && host=="" {ui_notice(self,"Enter a host address.");return}
 opts.address=fmt.ctprintf("%s",host);opts.port=u16(port);opts.token=self.online.launch ? self.online.party.grant.token : self.identity
 opts.latency_ms=u32(claimball_int("RCB_LATENCY",0));opts.jitter_ms=u32(claimball_int("RCB_JITTER",0));opts.loss_permyriad=u32(claimball_int("RCB_LOSS",0));opts.duplicate_permyriad=u32(claimball_int("RCB_DUPLICATE",0))
 opts.network.content=game.CONTENT;opts.remote_observed=true;opts.discover_epoch=claimball_int("RCB_COORD_PORT",0)==0 && !self.online.launch
 opts.network.hz,opts.network.lead,opts.network.snapshot_every=60,4,3
 if !rgd.session_comms_enable(&opts) || !rgd.session_diagnostics_enable(&opts) {ui_notice(self,"Could not configure social channels.");return}
 minimum:=u8(clamp(claimball_int("RCB_PLAYERS",manual || opts.role==.Solo ? 1 : 2),1,game.SEATS));goals:=u8(clamp(claimball_int("RCB_GOALS",3),1,255))
 err:=resume ? resume_pitch(self,opts) : open_session(self,game.initial(opts.role==.Server,minimum,goals,manual && opts.role!=.Server),opts)
 if err!=.None {if !resume {ui_notice(self,fmt.tprintf("Connection failed: %v",err))};return}
 self.ready=true;self.started_ms=gd.time_get_ticks_msec(gd.singleton_time())
 gd.control_release_focus(self.ui[0].name);gd.control_release_focus(self.ui[0].address);gd.control_release_focus(gd.spin_box_get_line_edit(self.ui[0].port))
 ui_notice(self,resume ? "Saved match restored." : opts.role==.Client || opts.role==.Observer ? "Joining the pitch…" : "Pitch open — invite players, then start.")
 gd.print_str("REPLAY_CLAIMBALL_READY")
}

effect_policy :: proc(e: net.Net_Event(game.Event)) -> v.Policy {
	return e.kind == .Gameplay && e.value.kind == .Goal ? v.Policy.Confirmed : v.Policy.Speculative
}

install_controls :: proc() {
	if gd.has_action("rcb_left") {return}
	rgd.bind_key("rcb_left", .A); rgd.bind_key("rcb_right", .D); rgd.bind_key("rcb_up", .W); rgd.bind_key("rcb_down", .S)
	rgd.bind_key("rcb_kick", .Space); rgd.bind_key("rcb_spike", .E)
}

sample :: proc(self: ^ReplayClaimball, w: game.World, seat: u16) -> game.Controls {
	c: game.Controls
	if !w.started || seat == 0 || self.keyboard_captured {return c}
	if self.contest_stop_tick != 0 && w.clock >= self.contest_stop_tick {return c}
	if self.bot == "" {
		if gd.is_action_pressed("rcb_left") {c.move[0] -= 1}; if gd.is_action_pressed("rcb_right") {c.move[0] += 1}
		if gd.is_action_pressed("rcb_up") {c.move[1] -= 1}; if gd.is_action_pressed("rcb_down") {c.move[1] += 1}
		if gd.is_action_pressed("rcb_kick") {c.buttons |= game.KICK}
		return c
	}
	me := w.players[seat - 1]
	b := w.ball.motion.position
	rel := b - me.motion.position
	steer: [2]f32
	if self.bot == "spiker" && !self.spiked {steer = p.unit2(rel)} else if self.bot == "striker" {
		to_goal := p.unit2([2]f32{me.team == 1 ? f32(640) : 0, 180} - b)
		aligned := rel[0] * to_goal[0] + rel[1] * to_goal[1]
		if aligned > 4 {
			steer = p.unit2(rel)
			if p.length_sq2(rel) < (game.KICK_REACH + 8) * (game.KICK_REACH + 8) {c.buttons |= game.KICK}
		} else {
			steer = p.unit2(b - to_goal * 31 - me.motion.position)
			if p.length_sq2(rel) < 29 * 29 * 4 {
				n := p.unit2(rel); tangent := [2]f32{-n[1], n[0]}
				if tangent[0] * steer[0] + tangent[1] * steer[1] < 0 {tangent = -tangent}
				steer = p.unit2(tangent - n * 0.6)
			}
		}
	}
	for axis in 0 ..< 2 {if steer[axis] > 0.3 {c.move[axis] = 1} else if steer[axis] < -0.3 {c.move[axis] = -1}}
	return c
}

replay_claimball_process :: proc(self: ^ReplayClaimball, dt: f64) {
	if self.ui[0].lobby==nil {return}
	profile_frame(self);browser_save_frame(self);browser_launch_frame(self);online_frame(self)
	self.keyboard_captured=ui_input(self);defer ui_frame(self)
	if !self.ready {return}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	f, available := rgd.session_state(self.session)
	seat := rgd.session_seat(self.session)
	control := sample(self, f.state, seat)
	if available && f.state.started && seat > 0 && !self.done && !self.keyboard_captured {
		want := gd.is_action_just_pressed("rcb_spike")
		// Two independent commands, close enough that both remain valid across
		// the runner's one-command-per-seat-per-tick service interval.
		if self.bot == "spiker" && !self.spiked && f.state.ball.hold == 0 && p.length_sq2(f.state.ball.motion.position - f.state.players[seat - 1].motion.position) < 30 * 30 {want = true}
		if want {
			seq, err := issue(self, game.Action{spike = true})
			if err == .None && !self.spiked {
				self.spiked, self.spike_at_ms, self.spike_at_tick, self.spike_first_sequence = true, now, f.tick, seq
				self.spike_from = f.state.ball.motion.position
				if node, found := rgd.nodes_get(&self.ball, 1); found {self.spike_from = gd.node2d_get_position(node); self.spike_node_start = true}
				_, second := issue(self, game.Action{spike = true})
				gd.print_str(fmt.tprintf("RCB_SPIKE_SENT tick=%d sequence=%d second=%v", f.tick, seq, second))
			}
		}
	}
	if err := frame_session(self, dt, control); err != .None {gd.print_str(fmt.tprintf("REPLAY_CLAIMBALL_FAIL frame=%v room=%v clock_poisoned=%v lease_poisoned=%v lease_now=%d deadline=%d client=%v head=%d confirmed=%d control=%v", err,self.room.phase,self.room.browser_clock.paired.poisoned,self.room.lease.poisoned,self.room.lease.now,self.room.lease.deadline,self.session.client.phase,self.session.client.timeline.head,self.session.client.journal.confirmed,self.room.control_error)); return}
	observe_room(self)
	observe_round(self)
	if !self.session.authority && self.session.client.resync_notice.serial > self.resync_seen {
		notice := self.session.client.resync_notice
		self.resync_seen = notice.serial
		gd.print_str(fmt.tprintf("RCB_RESYNC reason=%v head=%d confirmed=%d facts=%d incoming=%d dropped_seconds=%.6f", notice.reason,
		                        notice.head, notice.confirmed, notice.facts, notice.incoming_tick, self.session.clock.dropped_seconds))
	}
	if !self.session.authority && self.reset_seen != self.session.client.view_reset {
		self.reset_seen = self.session.client.view_reset; self.smoothing, self.claim = {}, {}
		self.name_submitted=false;self.name_sequence=0
		gd.print_str(fmt.tprintf("RCB_SEATED seat=%d reset=%d", self.session.client.seat, self.reset_seen))
	}
	if !self.session.authority && self.session.client.correction.serial > self.correction_seen {
		note := self.session.client.correction
		self.correction_seen = note.serial
		for i in 0 ..< game.SEATS {
			a, b := note.before.state.players[i], note.after.state.players[i]
			v.smooth_correct(&self.smoothing[i], a.motion.position, b.motion.position, discontinuity = a.connected != b.connected || note.before.state.round != note.after.state.round)
		}
		a, b := note.before.state.ball, note.after.state.ball
		v.smooth_correct(&self.smoothing[game.SEATS], a.motion.position, b.motion.position, discontinuity = a.reset != b.reset || note.before.state.round != note.after.state.round)
		error := f64(math.sqrt(p.length_sq2(a.motion.position - b.motion.position)))
		if error > 0.001 {self.correction_count += 1; self.correction_sum += error; self.correction_max = max(self.correction_max, error)}
	}
	changes: [320]v.Change(net.Net_Event(game.Event))
	n := rgd.session_changes(self.session, changes[:])
	for change in changes[:n] {
		e := change.occurrence.value
		if e.kind == .Action_Result && e.seat == seat && (change.kind == .Confirm || change.confirmed) && e.sequence > self.last_verdict {
			self.last_verdict = e.sequence
			if self.spike_first_sequence!=0 && e.sequence>=self.spike_first_sequence && e.sequence<=self.spike_first_sequence+1 {
				if e.applied {self.spike_applied += 1} else {self.spike_rejected += 1}
			}
			if e.sequence==self.name_sequence && !e.applied {self.name_submitted=false}
			gd.print_str(fmt.tprintf("RCB_ACTION sequence=%d applied=%v reason=%v", e.sequence, e.applied, e.reason))
		}
		if e.kind != .Gameplay || e.value.round != self.view_round || change.occurrence.id.epoch != self.view_epoch {continue}
		if change.kind == .Cancel {
			if change.occurrence.id == self.flash_id {self.flash_left = 0}
			if e.value.kind == .Kick {if e.seat == seat {self.local_canceled += 1} else {self.remote_canceled += 1}}
			continue
		}
		if change.kind != .Begin {continue}
		if e.value.kind == .Kick {
			if e.seat != seat && self.claim.active {self.remote_kicks_while_claimed += 1}
			self.flash_left, self.flash_id = 0.12, change.occurrence.id
			if e.seat == seat {
				self.local_kicks += 1
				if !self.session.authority && change.occurrence.id.tick > self.session.client.authority_frame.tick {self.speculative_kicks += 1}
			} else {self.remote_kicks += 1}
			gd.print_str(fmt.tprintf("RCB_KICK seat=%d tick=%d local=%v confirmed=%v", e.seat, change.occurrence.id.tick, e.seat == seat, change.confirmed))
		}
		if e.value.kind == .Spike && self.session.authority {gd.print_str(fmt.tprintf("RCB_SPIKE seat=%d tick=%d", e.seat, change.occurrence.id.tick))}
		if e.value.kind == .Spike && e.seat == seat {self.own_spike_seen = true}
	}
	social_frame(self)
	f, available = rgd.session_state(self.session)
	if available {
		paint(self, f, dt)
		if self.spiked && self.spike_node_start && self.own_spike_seen && !self.spike_visible {
			if node, found := rgd.nodes_get(&self.ball, 1); found && p.length_sq2(gd.node2d_get_position(node) - self.spike_from) > 12 * 12 {
				self.spike_visible = true
				gd.print_str(fmt.tprintf("RCB_SPIKE_LOCAL ticks=%d ms=%d acknowledged=%v", f.tick - self.spike_at_tick, gd.time_get_ticks_msec(gd.singleton_time()) - self.spike_at_ms, self.last_verdict >= self.spike_first_sequence))
			}
		}
		truth := self.session.authority ? f : self.session.client.authority_frame
		score := truth.state.score
		count := u16(score.left) + u16(score.right)
		if count > self.goal_seen {self.goal_seen = count; gd.print_str(fmt.tprintf("RCB_SCORE left=%d right=%d winner=%d", score.left, score.right, score.winner))}
		if score.winner != 0 && !self.done {self.done, self.done_ms = true, now}
		finish := self.done && now - self.done_ms > (self.session.authority ? 4000 : 2500)
		if self.contest_stop_tick != 0 {finish = truth.tick >= self.contest_stop_tick + (self.session.authority ? u64(720) : u64(600))}
		if finish && claimball_int("RCB_TEST", 0) == 1 {
			stats := self.session.authority ? self.session.server.stats : self.session.client.stats
			gd.print_str(fmt.tprintf("RCB_RESULT authority=%v left=%d right=%d winner=%d x=%.3f y=%.3f vx=%.6f vy=%.6f tick=%d kicks=%d spikes=%d local_kicks=%d speculative_kicks=%d remote_kicks=%d local_canceled=%d remote_canceled=%d accepted=%d rejected=%d",
			                        self.session.authority, score.left, score.right, score.winner, truth.state.ball.motion.position[0], truth.state.ball.motion.position[1],
			                        truth.state.ball.motion.velocity[0], truth.state.ball.motion.velocity[1], truth.tick,
			                        truth.state.kicks, truth.state.spikes, self.local_kicks, self.speculative_kicks, self.remote_kicks, self.local_canceled, self.remote_canceled, self.spike_applied, self.spike_rejected))
			gd.print_str(fmt.tprintf("RCB_METRICS corrections=%d replayed=%d ball_corrections=%d ball_error_sum=%.3f ball_error_max=%.3f rx_bytes=%d tx_bytes=%d resyncs=%d catchups=%d",
			                        stats.corrections, stats.replayed_ticks, self.correction_count, self.correction_sum, self.correction_max, stats.rx_bytes, stats.tx_bytes, stats.resyncs, stats.snapshot_catchups))
			gd.print_str(fmt.tprintf("RCB_GROUP predicted_members=%d max_claim=%.3f fast_far=%d watched_samples=%d watched_error=%.6f predicted_samples=%d predicted_error=%.6f", self.predicted_members,
			                        self.claim_max, self.fast_far_samples, self.watched_samples, self.watched_error_max, self.predicted_samples, self.predicted_error_max))
			gd.print_str(fmt.tprintf("RCB_CONTEST remote_kicks_while_claimed=%d dropped=%d duplicated=%d", self.remote_kicks_while_claimed, self.session.delay.dropped, self.session.delay.duplicated))
			gd.print_str(fmt.tprintf("RCB_PROFILE samples=%d total_us=%d max_us=%d max_depth=%d p95_upper_us=%d p99_upper_us=%d clock_errors=%d", stats.replay_samples,
			                        stats.replay_wall_us, stats.replay_max_us, stats.replay_max_depth, net.profile_percentile_upper(stats, 95), net.profile_percentile_upper(stats, 99), stats.profile_errors))
			gd.print_str("REPLAY_CLAIMBALL_PROCESS_OK"); gd.scene_tree_quit(gd.get_tree(self.owner), 0)
		}
	}
	self.flash_left = max(self.flash_left - dt, 0)
	if self.bot == "idle" && !self.stall_injected && available && f.tick >= 150 {
		stall := claimball_int("RCB_STALL_MS", 0)
		if stall > 0 {
			self.stall_injected = true
			gd.print_str(fmt.tprintf("RCB_STALL tick=%d ms=%d", f.tick, stall))
			gd.os_delay_msec(gd.singleton_os(), gd.Int(stall))
		}
	}
	if claimball_int("RCB_TEST", 0) == 1 && now - self.started_ms > 55000 {gd.print_str("REPLAY_CLAIMBALL_FAIL timeout"); gd.scene_tree_quit(gd.get_tree(self.owner), 1)}
}

paint :: proc(self: ^ReplayClaimball, frame: r.Frame(game.World), dt: f64) {
	w := frame.state
	if self.paint_round!=w.round {self.paint_round=w.round;self.smoothing={};self.claim={};self.ball_reset=0}
	if !w.started {gd.set_text(cast(gd.Object)self.status, "Waiting for the pitch to fill…"); return}
	seat := rgd.session_seat(self.session)
	observed := w
	if !self.session.authority {
		a, b, alpha, ok := net.client_observed(&self.session.client)
		if ok {
			observed = alpha >= 1 ? b.state : a.state
			for &player, i in observed.players {if a.state.round == b.state.round && a.state.players[i].connected == b.state.players[i].connected {player.motion.position = a.state.players[i].motion.position + (b.state.players[i].motion.position - a.state.players[i].motion.position) * alpha}}
			if a.state.round == b.state.round && a.state.ball.reset == b.state.ball.reset {observed.ball.motion.position = a.state.ball.motion.position + (b.state.ball.motion.position - a.state.ball.motion.position) * alpha}
		}
	}
	// A newly confirmed round is a cut for every avatar, even while the
	// watched interpolation clock still straddles the old match.
	if !self.session.authority && observed.round!=w.round && self.session.client.authority_frame.state.round==w.round {observed=self.session.client.authority_frame.state}
	drawn := observed.players
	if self.session.authority {drawn = w.players} else if seat != 0 {drawn[seat - 1] = w.players[seat - 1]}
	self.predicted_members = 0
	if self.session.authority || seat != 0 {for player in w.players {if player.connected {self.predicted_members += 1}}}
	instances: [game.SEATS]rgd.Instance2
	colors := [2]gd.Color{{0.35, 0.65, 1, 1}, {1, 0.62, 0.2, 1}}
	n := 0
	for player, i in drawn {if player.connected {
		pose := v.Pose2{position = player.motion.position}
		if self.session.authority || int(seat) == i + 1 {pose = v.smooth_present(&self.smoothing[i], pose, dt)}
		instances[n] = {key = u64(i + 1), pose = pose, scale = {1, 1}, color = colors[player.team - 1]}; n += 1
	}}
	rgd.nodes_present(&self.players, instances[:n])
	if self.ball_reset != w.ball.reset {self.ball_reset = w.ball.reset; self.smoothing[game.SEATS] = {}}
	predicted := v.smooth_present(&self.smoothing[game.SEATS], {position = w.ball.motion.position}, dt)
	pose := predicted
	if !self.session.authority {
		influencing := false
		distance_sq := f32(0)
		if seat != 0 && observed.round==w.round {
			distance_sq = p.length_sq2(w.ball.motion.position - w.players[seat - 1].motion.position)
			influencing = w.ball.hold == 0 && w.score.winner == 0 && distance_sq < 38 * 38
		}
		speed_sq := p.length_sq2(w.ball.motion.velocity)
		retain_reset := self.claim.weight > 0 && w.ball.reset != observed.ball.reset
		v.claim_update(&self.claim, influencing, speed_sq, dt, retain_reset = retain_reset)
		if self.session.client.spectator {self.claim = {}}
		self.claim_max = max(self.claim_max, self.claim.weight)
		if seat != 0 && !influencing && distance_sq >= 38 * 38 && speed_sq > 0.6 * 0.6 && self.claim.weight == 1 {self.fast_far_samples += 1}
		pose = observed.round==w.round ? v.claim_pose(self.claim, {position = observed.ball.motion.position}, predicted) : predicted
	}
	ball := [1]rgd.Instance2{{key = 1, pose = pose, scale = {1, 1}, color = self.flash_left > 0 ? gd.Color{1, 0.75, 0.2, 1} : gd.Color{1, 1, 1, 1}}}
	rgd.nodes_present(&self.ball, ball[:])
	if !self.session.authority && self.claim.weight == 1 {
		if node, found := rgd.nodes_get(&self.ball, 1); found {
			self.predicted_samples += 1
			self.predicted_error_max = max(self.predicted_error_max, math.sqrt(p.length_sq2(gd.node2d_get_position(node) - predicted.position)))
		}
	}
	if !self.session.authority && self.claim.weight == 0 && observed.round==w.round {
		if node, found := rgd.nodes_get(&self.ball, 1); found {
			self.watched_samples += 1
			self.watched_error_max = max(self.watched_error_max, math.sqrt(p.length_sq2(gd.node2d_get_position(node) - observed.ball.motion.position)))
		}
	}
	score := self.session.authority ? w.score : self.session.client.authority_frame.state.score
	gd.set_string(cast(gd.Object)self.status, "text", fmt.ctprintf("LEFT %d — %d RIGHT   %s", score.left, score.right, score.winner == 0 ? "" : "MATCH OVER"))
}

replay_claimball_exit_tree :: proc(self: ^ReplayClaimball) {
	online_close(self);browser_save_close(self);rgd.browser_identity_close(&self.browser_identity);delete(self.browser_launch)
	co.destroy(&self.comms);dg.destroy(&self.diagnostics);rgd.name_profile_close(&self.name_profile)
	rgd.nodes_destroy(&self.players); rgd.nodes_destroy(&self.ball)
	close_session(self); delete(self.bot)
}
