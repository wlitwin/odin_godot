package replay_slopball3d

import "core:fmt"
import "core:reflect"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import own "godot:replay/owned"
import net "godot:replay/net"
import auth "godot:replay/authority"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import game "../shared/pitch"

Physics_Recovery :: struct {
	point: auth.Point,
	frame: r.Frame(game.World),
	checked, seed_epoch: u64,
	restored_exact, restored_moving, seeded: bool,
	seed,restored_pose: own.Pose3,
}

open_session :: proc(self: ^ReplaySlopball3d, initial: game.World, options: rgd.Session_Options) -> net.Error {
 if self.online.launch {
  opts,ok:=rgd.party_room_options(&self.online.party,options);if !ok {return .Invalid_Config}
  opts.session.discover_epoch=false
  if options.role==.Observer {opts.session.replication.accept_checkpoints=false}
  self.session=&self.room.session
  return rgd.room_open(&self.room,r.Frame(game.World){state=initial},game.model(),opts)
 }
	port := slopball3d_int("RS3_COORD_PORT", 0)
	if port == 0 {self.session=&self.standalone;return rgd.session_open(self.session, r.Frame(game.World){state = initial}, game.model(), options)}
	member := slopball3d_int("RS3_MEMBER", 0)
	key, ok := control_key(slopball3d_param("RS3_COORD_KEY", ""))
	if port < 1 || port > 65535 || member < 1 || member > 3 || !ok {return .Invalid_Config}
	room := rgd.Room_Options{identity = {u64(member), u64(100 + member)}, key = key, room = 47,
	        coordinator = "127.0.0.1", control_port = u16(port), bootstrap = member == 1, session = options}
	if member == 1 {room.successor, room.successor_seat = {2, 102}, 2}
	if member == 2 {room.successor, room.successor_seat = {1, 101}, 1}
	room.session.replication.accept_checkpoints = member <= 2
	self.session = &self.room.session
	return rgd.room_open(&self.room, r.Frame(game.World){state = initial}, game.model(), room)
}

control_key :: proc(text: string) -> (auth.Key, bool) {
	key: auth.Key
	if len(text) != 64 {return key, false}
	for c, i in text {
		digit := c >= '0' && c <= '9' ? int(c - '0') : c >= 'a' && c <= 'f' ? int(c - 'a') + 10 : -1
		if digit < 0 {return key, false}
		key[i / 2] = key[i / 2] << 4 | u8(digit)
	}
	return key, true
}

moving :: proc(w: game.World) -> bool {
	v := w.ball.value.linear
	return w.started && w.won == 0 && w.ball.owner == 1 && w.ball.sequence > 0 && v[0] * v[0] + v[2] * v[2] > 1
}

observe_recovery :: proc(self: ^ReplaySlopball3d) {
 if slopball3d_int("RS3_PROBE",slopball3d_int("RS3_COORD_PORT",0)!=0 ? 1 : 0)!=1 {return}
	p := &self.recovery_probe[0]
	prepared := &self.room.prepared
	if prepared.ready && prepared.point != p.point {
		cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS); defer net.checkpoint_destroy(&cp)
		codec := &self.session.link.incoming.archive_codec
		if !codec.ready {codec = nil}
		if net.checkpoint_decode(&cp, prepared.bytes, game.model(), game.CONTENT, codec = codec) == .None {p.point, p.frame = prepared.point, cp.frame}
	}
	if self.room.migrations > p.checked && self.session.authority && self.room.recovery.to_epoch == self.session.server.cfg.epoch {
		p.checked = self.room.migrations
		frame, found := r.read(&self.session.server.timeline, self.room.recovery.checkpoint_tick)
		p.restored_exact = found && p.point == self.room.lease.view.recovered && reflect.equal(frame, p.frame)
		p.restored_moving = p.restored_exact && moving(frame.state)
		if p.restored_exact {p.restored_pose=frame.state.ball.value}
		gd.print_str(fmt.tprintf("RS3_PHYSICS_RESTORED exact=%v moving=%v tick=%d owner=%d sequence=%d vx=%.6f vy=%.6f vz=%.6f", p.restored_exact,
		                        p.restored_moving, frame.tick, frame.state.ball.owner, frame.state.ball.sequence, frame.state.ball.value.linear[0], frame.state.ball.value.linear[1], frame.state.ball.value.linear[2]))
	}
}

observe_physics_seed :: proc(self: ^ReplaySlopball3d, state: own.State(own.Pose3), actual: own.Pose3) {
	if !self.room.ready || state.epoch < 2 {return}
	p := &self.recovery_probe[0]
	if p.seed_epoch == state.epoch {return}
	p.seed_epoch, p.seed = state.epoch, actual
	position_error, velocity_error, speed, rotation_dot := f32(0), f32(0), f32(0), f32(0)
	for i in 0 ..< 3 {
		position_error += abs(actual.position[i] - state.value.position[i])
		velocity_error += abs(actual.linear[i] - state.value.linear[i]) + abs(actual.angular[i] - state.value.angular[i])
		speed += abs(actual.linear[i])
	}
	for i in 0 ..< 4 {rotation_dot += actual.rotation[i] * state.value.rotation[i]}
	p.seeded = position_error < 0.0001 && velocity_error < 0.0001 && abs(rotation_dot) > 0.99999 && speed > 0.1
	gd.print_str(fmt.tprintf("RS3_RECOVERY_SEED epoch=%d exact=%v position_error=%.9f velocity_error=%.9f rotation_dot=%.9f vx=%.6f vy=%.6f vz=%.6f", state.epoch, p.seeded,
	                        position_error, velocity_error, abs(rotation_dot), actual.linear[0], actual.linear[1], actual.linear[2]))
}

@(gd_method)
replay_slopball3d_set_bot :: proc(self: ^ReplaySlopball3d, value: gd.String) {
	defer gd.free_string(value)
	text := gd.gd_string_to_odin(value)
	delete(self.bot); self.bot = strings.clone(text)
	self.bot_selected = true
}

@(gd_method)
replay_slopball3d_handoff :: proc(self: ^ReplaySlopball3d) -> bool {return rgd.room_handoff(&self.room) == .None}

@(gd_method)
replay_slopball3d_probe :: proc(self: ^ReplaySlopball3d, name: gd.String) -> gd.Int {
	defer gd.free_string(name)
	key := gd.gd_string_to_odin(name)
	if self.session == nil {return 0}
	f, _ := rgd.session_authority_state(self.session)
	w := f.state; p := &self.recovery_probe[0]
	switch key {
	case "steady": return gd.Int(self.session.ready && !self.session.fenced && (self.session.authority || self.session.client.phase == .Running))
	case "players": count := gd.Int(0); for player in w.players {if player.connected {count += 1}}; return count
	case "head": return gd.Int(f.tick)
	case "seat": return gd.Int(rgd.session_seat(self.session))
	case "epoch": return gd.Int(self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch)
	case "authority": return gd.Int(self.session.authority)
	case "moving": return gd.Int(moving(w))
	case "owner": return gd.Int(w.ball.owner)
	case "body_epoch": return gd.Int(w.ball.epoch)
	case "body_revision": return gd.Int(w.ball.revision)
	case "body_sequence": return gd.Int(w.ball.sequence)
	case "goals": return gd.Int(w.left) + gd.Int(w.right)
	case "right": return gd.Int(w.right)
	case "kicks": return gd.Int(self.kicks)
	case "moving_backup": return gd.Int(p.point.archive.sequence != 0 && moving(p.frame.state) && self.room.rpc.reply.prepared && self.room.rpc.reply.point == p.point)
	case "backup_tick": return gd.Int(self.session.authority ? self.session.link.outgoing.acknowledged.archive.tick : p.point.archive.tick)
	case "prepared_tick": return self.room.rpc.reply.prepared ? gd.Int(self.room.rpc.reply.point.archive.tick) : 0
	case "restored_exact": return gd.Int(p.restored_exact)
	case "restored_moving": return gd.Int(p.restored_moving)
	case "restored_goals": return gd.Int(p.frame.state.left) + gd.Int(p.frame.state.right)
	case "restored_right": return gd.Int(p.frame.state.right)
	case "spinning_backup": pose:=p.frame.state.ball.value;return gd.Int(p.point.archive.sequence!=0 && moving(p.frame.state) && pose.angular[0]*pose.angular[0]+pose.angular[1]*pose.angular[1]+pose.angular[2]*pose.angular[2]>0.25 && abs(pose.rotation[0])+abs(pose.rotation[1])+abs(pose.rotation[2])>0.05)
	case "complete_backup": return gd.Int(p.point.archive.sequence!=0 && game.state_valid(p.frame.state))
	case "seeded": return gd.Int(p.seeded)
	case "recovery_ready": return gd.Int(self.room.recovery.ready)
	case "recovery_tick": return gd.Int(self.room.recovery.checkpoint_tick)
	case "recovery_kind": return gd.Int(self.room.lease.view.recovery)
	case "lost_ticks": return gd.Int(self.room.recovery.known_lost_ticks)
	case "interruption": return gd.Int(self.room.recovery.interruption_ms)
	case "room_phase": return gd.Int(self.room.phase)
	case "control_error": return gd.Int(self.room.control_error)
	case "link_error": return gd.Int(self.session.link.error)
	case: return -1
	}
}

@(gd_method)
replay_slopball3d_probe_hash :: proc(self: ^ReplaySlopball3d, tick: gd.Int) -> gd.Int {
	if self.session == nil || !self.session.ready || tick < 0 {return -1}
	f: r.Frame(game.World); found := false
	if self.session.authority {f, found = r.read(&self.session.server.timeline, u64(tick))} else {
		c := &self.session.client; at := int(u64(tick) % u64(c.cfg.history))
		if c.observed_valid[at] && c.observed[at].tick == u64(tick) {f, found = c.observed[at], true}
	}
	if !found {return -1}
	codec := self.session.authority ? &self.session.server.codecs.state : &self.session.client.codecs.state
	bytes := make([]u8, codec.wire_size, context.temp_allocator)
	if sc.encode(codec, f.state, bytes).error != .None {return -1}
	return gd.Int(sc.digest(bytes) & 0x7fff_ffff_ffff_ffff)
}

room_ui :: proc(self:^ReplaySlopball3d) {
 handoff:=gd.get_node(self.owner,"UI/Handoff");notice:=gd.get_node(self.owner,"UI/Recovery")
 gd.canvas_item_set_visible(handoff,self.room.ready && self.session.ready && self.session.authority)
 gd.base_button_set_disabled(cast(gd.Button)handoff,!self.room.ready || self.room.phase!=.Hosting || self.room.options.successor_seat==0)
 gd.canvas_item_set_visible(notice,self.room.ready)
 if self.room.ready {
  status:=rgd.room_backup_status(&self.room)
  gd.set_string(notice,"text",fmt.ctprintf("%s",rgd.room_recovery_message(&self.room,status)))
 }
}

@(gd_method)
replay_slopball3d_recovery_pose :: proc(self:^ReplaySlopball3d,which:string)->gd.String {
 if which!="seed" && which!="restored" && which!="live" {return gd.new_string_odin("null")}
 pose:=which=="seed" ? self.recovery_probe[0].seed : self.recovery_probe[0].restored_pose
 if which=="live" {frame,ok:=rgd.session_authority_state(self.session);if !ok {return gd.new_string_odin("null")};pose=frame.state.ball.value}
 return gd.new_string_odin(fmt.tprintf("[%v,%v,%v,%v]",pose.position,pose.rotation,pose.linear,pose.angular))
}
