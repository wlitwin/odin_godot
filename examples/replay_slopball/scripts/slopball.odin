//gd:extends Node2D
//gd:class ReplaySlopball
package replay_slopball

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import own "godot:replay/owned"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/pitch"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

ReplaySlopball :: struct {
	owner: gd.Node2d,
	ui:[1]Slopball_UI,
	comms:co.Comms,
	diagnostics:dg.Diagnostics,
	browser_save:[1]Slopball_Browser_Save,
	identity:net.Token,
	display_name:lb.Name,
	name_profile:storagegd.Name_Profile,
	online:Slopball_Online,
	browser_identity:storagegd.Browser_Identity,
	profile_identity_ready,profile_name_loaded:bool,
	browser_launch:string,
	views_ready,keyboard_captured,profile_enabled,name_submitted:bool,
	name_sequence:u64,
	saved_tick,saved_hash,restored_tick,restored_hash:u64,
	restored_exact,save_seeded,save_seed_checked:bool,
	restored_ball,save_seed:own.Pose2,
	status: gd.Label `gd:"onready=Status"`,
	session: ^rgd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS),
	standalone: rgd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS),
	room: rgd.Room(game.World, game.Control, game.Action, game.Event, game.SEATS),
	recovery_probe: [1]Physics_Recovery,
	bodies: [game.SEATS + 1]scenegd.Body2,
	body_layers:[game.SEATS+1][2]gd.Int,
	world: [1]game.World,
	intent: [2]i8,
	buttons: r.Buttons,
	bot: string,
	ready, have_world, test, reported, bot_selected: bool,
	started_ms, finished_ms, last_revision, probe_tick: u64,
	kick_left: f64,
	kicks, previews, goals_seen: u32,
	view_round:u32,
}

replay_slopball_ready :: proc(self: ^ReplaySlopball) {
	self.session = &self.standalone
	if !gd.has_action("rsl_left") {
		inputgd.bind_key("rsl_left", .A); inputgd.bind_key("rsl_right", .D)
		inputgd.bind_key("rsl_up", .W); inputgd.bind_key("rsl_down", .S); inputgd.bind_key("rsl_kick", .Space)
	}
	for &body, i in self.bodies {
		path: cstring = i == game.SEATS ? "res://views/ball.tscn" : "res://views/kicker.tscn"
		node := scenegd.scene_instance(self.owner, path)
		if node == nil {slop_fail(self, "scene"); return}
		skin := cast(gd.Node2d)gd.get_node(node, i == game.SEATS ? "Look" : "Skin")
		if !scenegd.body2_attach(&body, cast(gd.Physics_Body2d)node, i == game.SEATS ? .Rigid : .Character, skin) {slop_fail(self, "body"); return}
		self.body_layers[i]={gd.Int(gd.collision_object2d_get_collision_layer(cast(gd.Collision_Object2d)node)),gd.Int(gd.collision_object2d_get_collision_mask(cast(gd.Collision_Object2d)node))}
		if i != game.SEATS {
			gd.canvas_item_set_modulate(cast(gd.Canvas_Item)node, gd.peer_color(i + 1))
			gd.canvas_item_set_visible(cast(gd.Canvas_Item)node, false)
			gd.collision_object2d_set_collision_layer(cast(gd.Collision_Object2d)node, 0)
			gd.collision_object2d_set_collision_mask(cast(gd.Collision_Object2d)node, 0)
		}
	}
	if !self.bot_selected {self.bot = strings.clone(slopball_param("RSL_BOT", ""))}
 self.identity=storagegd.session_token(slopball_param("RSL_TOKEN",""))
 self.views_ready=true;co.init(&self.comms);dg.init(&self.diagnostics)
 reset_bodies(self);ui_ready(self);online_ready(self)
 role:=slopball_param("RSL_ROLE",slopball_int("RSL_COORD_PORT",0)!=0 ? "host" : "")
 if role!="" {when gd.IS_WEB {self.browser_launch=strings.clone(role)} else {connect_pitch(self,role,false,slopball_int("RSL_RESUME",0)==1)}}
 gd.print_str("REPLAY_SLOPBALL_UI_READY")
}

connect_pitch :: proc(self:^ReplaySlopball,role:string,manual:bool,resume:bool=false) {
 if self.ready || !self.views_ready || (self.online.party.active && !self.online.launch) {return}
 if !profile_available(self) {ui_notice(self,self.name_profile.failed ? "Could not load your saved name. Existing data was kept." : "Loading the player profile…");return}
 when gd.IS_WEB {if !self.online.launch && role!="solo" {ui_notice(self,"Browser multiplayer uses a configured party service.");return}}
 options:=rgd.SESSION_OPTIONS
 switch role {case "solo":options.role=.Solo;case "host":options.role=.Host;case "server":options.role=.Server;case "client":options.role=.Client;case "observer":options.role=.Observer;case:return}
 port:=int(gd.range_get_value(self.ui[0].port));if port<1 || port>65535 {ui_notice(self,"Use a port from 1 to 65535.");return}
 value:=gd.line_edit_get_text(self.ui[0].name);name,valid:=lb.name(gd.gd_string_to_odin(value));gd.free_string(value)
 if !valid {ui_notice(self,"Enter a display name.");return}
 token,profile_ok:=profile_connect(self,name);if !profile_ok {return};self.identity=token
 self.display_name=name
 address:=gd.line_edit_get_text(self.ui[0].address);defer gd.free_string(address);host:=strings.trim_space(gd.gd_string_to_odin(address))
 if (options.role==.Client || options.role==.Observer) && host=="" {ui_notice(self,"Enter a host address.");return}
 options.address=fmt.ctprintf("%s",host);options.port=u16(port);options.token=self.online.launch ? self.online.party.grant.token : self.identity
 options.latency_ms,options.jitter_ms=u32(slopball_int("RSL_LATENCY",0)),u32(slopball_int("RSL_JITTER",0))
 options.loss_permyriad,options.duplicate_permyriad=u32(slopball_int("RSL_LOSS",0)),u32(slopball_int("RSL_DUPLICATE",0))
 options.network.content,options.network.hz,options.network.lead=game.CONTENT,60,4
 options.network.snapshot_every,options.network.watch_delay=1,3
 options.discover_epoch=slopball_int("RSL_COORD_PORT",0)==0 && !self.online.launch
 if !rgd.session_comms_enable(&options) || !debuggd.session_diagnostics_enable(&options) {ui_notice(self,"Could not configure social channels.");return}
 minimum:=u8(clamp(slopball_int("RSL_PLAYERS",manual || options.role==.Solo ? 1 : 2),1,game.SEATS))
 goals:=u8(clamp(slopball_int("RSL_GOALS",3),1,255))
 gd.engine_set_physics_ticks_per_second(gd.singleton_engine(),60)
 err:=resume ? resume_pitch(self,options) : open_session(self,game.initial(options.role==.Server,minimum,goals,manual),options)
 if err!=.None {if !resume {ui_notice(self,fmt.tprintf("Connection failed: %v",err))};return}
 self.test=slopball_int("RSL_TEST",0)==1;self.probe_tick=u64(max(slopball_int("RSL_PROBE_TICK",600),1))
 self.started_ms,self.ready=gd.time_get_ticks_msec(gd.singleton_time()),true
 gd.control_release_focus(self.ui[0].name);gd.control_release_focus(self.ui[0].address);gd.control_release_focus(gd.spin_box_get_line_edit(self.ui[0].port))
 ui_notice(self,resume ? "Saved pitch restored." : "Pitch open — start when everyone is ready.");gd.print_str("REPLAY_SLOPBALL_READY")
}

replay_slopball_process :: proc(self: ^ReplaySlopball, dt: f64) {
	if self.ui[0].lobby==nil {return}
 profile_frame(self);browser_save_frame(self);browser_launch_frame(self);online_frame(self)
 self.keyboard_captured=ui_input(self);defer ui_frame(self)
	if !self.ready {return}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	if self.test && now - self.started_ms > 45000 {slop_fail(self, "timeout"); return}
	r.buttons_set(&self.buttons, !self.keyboard_captured && gd.is_action_pressed("rsl_kick") ? 1 : 0)
 if self.keyboard_captured || !self.have_world || !self.world[0].started {self.buttons={};self.intent={}}
	control := game.Control{intent = self.intent}
	seat := rgd.session_seat(self.session)
	physics_frame := gd.engine_get_physics_frames(gd.singleton_engine())
	if seat != 0 && self.have_world {
		control.player, _ = scenegd.body2_sample(&self.bodies[seat - 1], physics_frame)
		control.ball, _ = scenegd.body2_sample(&self.bodies[game.SEATS], physics_frame)
	}
	err := self.room.ready ? rgd.room_frame(&self.room, dt, control) : rgd.session_frame(self.session, dt, control)
	if err != .None {slop_fail(self, fmt.tprintf("frame %v", err)); return}
	if self.room.ready {observe_recovery(self)}
	frame, live := rgd.session_authority_state(self.session)
	if live {
  if self.view_round!=frame.state.round {
   self.view_round=frame.state.round;self.kicks,self.previews,self.goals_seen=0,0,0
   self.kick_left=0;self.buttons={};self.intent={};self.reported=false;self.finished_ms=0
  }
		self.world[0], self.have_world = frame.state, true
		presentation := frame.state
		if !self.session.authority {
			a, b, alpha, ok := net.client_observed(&self.session.client)
			if ok {
				for &player, i in presentation.players {player.body = blended(a.state.players[i].body, b.state.players[i].body, alpha)}
				presentation.ball = blended(a.state.ball, b.state.ball, alpha)
			}
		}
		for &body, i in self.bodies {
			state: own.State(own.Pose2)
			shown: own.State(own.Pose2)
			active := true
			if i == game.SEATS {state, shown = frame.state.ball, presentation.ball
    gd.canvas_item_set_visible(cast(gd.Canvas_Item)body.body,frame.state.started)
    gd.collision_object2d_set_collision_layer(cast(gd.Collision_Object2d)body.body,self.body_layers[i][0])
    gd.collision_object2d_set_collision_mask(cast(gd.Collision_Object2d)body.body,self.body_layers[i][1])
   } else {
				active = frame.state.players[i].connected
				state, shown = frame.state.players[i].body, presentation.players[i].body
				gd.canvas_item_set_visible(cast(gd.Canvas_Item)body.body, active)
				gd.collision_object2d_set_collision_layer(cast(gd.Collision_Object2d)body.body, active ? self.body_layers[i][0] : 0)
				gd.collision_object2d_set_collision_mask(cast(gd.Collision_Object2d)body.body, active ? self.body_layers[i][1] : 0)
			}
			eligible := active && frame.state.started
			if i == game.SEATS && frame.tick < frame.state.kickoff_until {eligible = false}
			old_scope := body.driver.scope
			old_role := body.driver.role
			if err := scenegd.body2_sync(&body, state, seat, self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch, frame.tick, eligible, dt, &shown); err != .None {slop_fail(self, fmt.tprintf("sync %v", err)); return}
			// Enabling a previously observed scope also reseeds the solver. Room
			// installation can publish its scope before the local seat is visible.
			if i == game.SEATS && body.driver.role == .Owner && (body.driver.scope != old_scope || old_role == .Observer) {observe_physics_seed(self, state, scenegd.body2_read(&body));observe_save_seed(self,state,scenegd.body2_read(&body))}
		}
		if frame.state.ball.revision != self.last_revision {
			self.last_revision = frame.state.ball.revision
			gd.print_str(fmt.tprintf("RSL_OWNER tick=%d owner=%d revision=%d vx=%.3f vy=%.3f spin=%.3f", frame.tick, frame.state.ball.owner, frame.state.ball.revision,
			                        frame.state.ball.value.linear[0], frame.state.ball.value.linear[1], frame.state.ball.value.angular))
		}
		gd.set_string(cast(gd.Object)self.status, "text", fmt.ctprintf("Slopball   %d : %d   Ball owner %d", frame.state.left, frame.state.right, frame.state.ball.owner))
	} else if self.have_world {
		for &body in self.bodies {scenegd.body2_suspend(&body, dt)}
	}
	changes: [320]v.Change(net.Net_Event(game.Event))
	for {
		n := rgd.session_changes(self.session, changes[:]); if n == 0 {break}
		for change in changes[:n] {
			e := change.occurrence.value
   if e.kind==.Action_Result && e.seat==seat && e.sequence==self.name_sequence && (change.kind==.Confirm || change.confirmed) && !e.applied {self.name_submitted=false}
			if change.kind == .Begin && e.kind == .Gameplay && e.value.round==self.view_round && e.value.kind == .Goal {
				self.goals_seen += 1
				gd.print_str(fmt.tprintf("RSL_GOAL tick=%d left=%d right=%d", change.occurrence.id.tick, e.value.score[0], e.value.score[1]))
			}
		}
	}
	social_frame(self)
	if self.test && live && frame.tick >= self.probe_tick && !self.reported {
		if frame.state.won == 0 {if frame.tick > self.probe_tick + 1200 {slop_fail(self, "no winner")}; return}
		self.reported, self.finished_ms = true, now + 1800
		gd.print_str(fmt.tprintf("RSL_RESULT seat=%d tick=%d owner=%d revision=%d left=%d right=%d won=%d x=%.3f y=%.3f handoffs=%d kicks=%d previews=%d goals=%d",
		                        seat, frame.tick, frame.state.ball.owner, frame.state.ball.revision, frame.state.left, frame.state.right, frame.state.won,
		                        frame.state.ball.value.position[0], frame.state.ball.value.position[1], frame.state.handoffs, self.kicks, self.previews, self.goals_seen))
		gd.print_str("REPLAY_SLOPBALL_PEER_OK")
	}
	if self.finished_ms != 0 && now >= self.finished_ms {gd.scene_tree_quit(gd.get_tree(self.owner), 0)}
}

replay_slopball_physics_process :: proc(self: ^ReplaySlopball, dt: f64) {
	if !self.ready || !self.have_world {return}
	self.kick_left = max(0, self.kick_left - dt)
	seat := rgd.session_seat(self.session)
	if seat == 0 || !self.world[0].started || !self.world[0].players[seat - 1].connected {return}
	actor, ball := &self.bodies[seat - 1], &self.bodies[game.SEATS]
	if !scenegd.body2_simulating(actor) {return}
	me, target := scenegd.body2_read(actor), scenegd.body2_read(ball)
	direction: [2]f32
	if self.bot == "striker" && self.world[0].won == 0 {
		goal := [2]f32{game.team(seat) == 1 ? f32(640) : 0, 180}
		behind := p.unit2(target.position - goal)
		direction = p.unit2(target.position + behind * 4 - me.position)
	} else if self.bot == "chaser" {direction = p.unit2(target.position - me.position)} else if self.bot == "" {
		if gd.is_action_pressed("rsl_left") {direction[0] -= 1}; if gd.is_action_pressed("rsl_right") {direction[0] += 1}
		if gd.is_action_pressed("rsl_up") {direction[1] -= 1}; if gd.is_action_pressed("rsl_down") {direction[1] += 1}
		direction = p.unit2(direction)
	}
	if self.keyboard_captured {direction={}}
	self.intent = {}
	for axis in 0 ..< 2 {if direction[axis] > 0.1 {self.intent[axis] = 1} else if direction[axis] < -0.1 {self.intent[axis] = -1}}
	gd.character_body2d_set_velocity(cast(gd.Character_Body2d)actor.body, {direction[0] * game.KICKER_SPEED, direction[1] * game.KICKER_SPEED})
	gd.character_body2d_move_and_slide(cast(gd.Character_Body2d)actor.body)
	me = scenegd.body2_read(actor)
	distance := p.length_sq2(target.position - me.position)
	playing := self.world[0].won == 0 && self.world[0].tick >= self.world[0].kickoff_until
	if playing && distance <= game.DRIBBLE_R * game.DRIBBLE_R && p.length_sq2(direction) > 0 {
		if slopball_int("RSL_PREVIEW", 1) == 1 && scenegd.body2_preview(ball, self.world[0].ball) {self.previews += 1}
		if scenegd.body2_simulating(ball) && p.length_sq2(target.linear) < game.KICKER_SPEED * game.KICKER_SPEED * 2 {
			gd.rigid_body2d_apply_central_impulse(cast(gd.Rigid_Body2d)ball.body, {direction[0] * game.DRIBBLE_NUDGE, direction[1] * game.DRIBBLE_NUDGE})
		}
	}
	want := !self.keyboard_captured && ((self.bot == "striker" && playing) || (self.bot == "" && self.buttons.pressed & 1 != 0))
	if want && self.kick_left == 0 && scenegd.body2_simulating(ball) && distance <= game.KICK_REACH * game.KICK_REACH {
		aim := p.unit2(target.position - me.position)
		if self.bot == "striker" {aim = p.unit2([2]f32{game.team(seat) == 1 ? f32(640) : 0, 180} - target.position)}
		gd.rigid_body2d_apply_central_impulse(cast(gd.Rigid_Body2d)ball.body, {aim[0] * game.KICK_POWER, aim[1] * game.KICK_POWER})
		self.kick_left = 0.25; self.kicks += 1
		gd.print_str("RSL_KICK")
	}
	r.buttons_consume(&self.buttons)
}

blended :: proc(a, b: own.State(own.Pose2), alpha: f32) -> own.State(own.Pose2) {
	if own.scope(a) != own.scope(b) || a.discontinuity != b.discontinuity {return alpha >= 1 ? b : a}
	out := a
	pose := v.pose_blend({a.value.position, a.value.rotation}, {b.value.position, b.value.rotation}, alpha)
	out.value.position, out.value.rotation = pose.position, pose.angle
	out.value.linear = a.value.linear + (b.value.linear - a.value.linear) * alpha
	out.value.angular = a.value.angular + (b.value.angular - a.value.angular) * alpha
	return out
}

slop_fail :: proc(self: ^ReplaySlopball, message: string) {gd.print_str(fmt.tprintf("REPLAY_SLOPBALL_FAIL %s", message)); gd.scene_tree_quit(gd.get_tree(self.owner), 1)}
replay_slopball_exit_tree :: proc(self: ^ReplaySlopball) {
	for &body in self.bodies {scenegd.body2_destroy(&body)}
	if self.room.ready {rgd.room_close(&self.room)} else if self.session != nil {rgd.session_close(self.session)}
	online_close(self);browser_save_close(self);storagegd.browser_identity_close(&self.browser_identity);delete(self.browser_launch)
	co.destroy(&self.comms);dg.destroy(&self.diagnostics);storagegd.name_profile_close(&self.name_profile)
	delete(self.bot)
}
