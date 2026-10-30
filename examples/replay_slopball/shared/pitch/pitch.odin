package slop_pitch

import "core:math"
import r "godot:replay"
import net "godot:replay/net"
import own "godot:replay/owned"
import p "godot:replay/play"
import v "godot:replay/view"
import lb "godot:replay/lobby"

SEATS :: 4
CONTENT :: u64(0x52534c4f50423234)
INTENT_STRIDE :: f32(0.6)
KICKER_SPEED :: f32(150)
KICK_REACH :: f32(26)
KICK_POWER :: f32(260)
DRIBBLE_R :: f32(21)
DRIBBLE_NUDGE :: f32(14)
TOUCH_R :: f32(44)
CONTACT_R :: f32(22)
GRANT_EDGE :: f32(12)
BALL_SLOW :: f32(60)
GRANT_TICKS :: u64(27)
CHALLENGE_TICKS :: u64(18)
KICKOFF_TICKS :: u64(72)

Player :: struct {initialized, connected, named: bool, body: own.State(own.Pose2), stride_scope:own.Scope, stride_position:[2]f32}
World :: struct {
	players: [SEATS]Player,
	names: [SEATS]lb.Name,
	manual_start: bool,
	ball: own.State(own.Pose2),
	tick, kickoff_until, grant_after, challenge_since: u64,
	challenger: u16,
	started: bool,
	round:u32,
	minimum, goals_to, left, right, won: u8,
	handoffs, rejected: u32,
}
Action :: struct {start:bool,name:lb.Name,restart_round:u32}
Control :: struct {player, ball: own.Sample(own.Pose2), intent: [2]i8}
Event_Kind :: enum u8 {Started, Offer, Handoff, Goal, Reset}
Event :: struct {round:u32,kind: Event_Kind, owner: u16, revision: u64, position: [2]f32, score: [2]u8}

rules :: proc() -> own.Rules(own.Pose2) {
	return {valid = proc(user: rawptr, value: own.Pose2) -> bool {return own.pose2_valid(value, {{-64, -64}, {704, 424}, 1500, 150})},
	        transition = proc(user: rawptr, before, after: own.Pose2, elapsed: u64) -> bool {
		        distance := after.position - before.position
		        allowed := f64(min(elapsed, 600) + 12) * 1500 / 60
		        return f64(p.length_sq2(distance)) <= allowed * allowed
	        }}
}

team :: proc(seat: u16) -> u8 {return seat % 2 == 1 ? 1 : 2}
spawn :: proc(seat: u16) -> own.Pose2 {
	offsets := [4]f32{-70, 70, -120, 120}
	side := team(seat)
	return {position = {side == 1 ? f32(200) : 440, 180 + offsets[((int(seat) - int(side)) / 2) % 4]}}
}

initial :: proc(dedicated: bool = false, minimum: u8 = 1, goals_to: u8 = 3, manual_start:bool=false) -> World {
	w := World{round=1,minimum = minimum, goals_to = goals_to, manual_start=manual_start}
	for &name,i in w.names {name=lb.seat_name(u16(i+1))}
	for &player, i in w.players {assert(own.init(&player.body, {1, u32(i), 1}, 1, 0, u16(i + 1), spawn(u16(i + 1)), rules()) == .None);reset_stride(&player)}
	assert(own.init(&w.ball, {2, 0, 1}, 1, 0, dedicated ? 0 : 1, own.Pose2{position = {320, 180}}, rules()) == .None)
	return w
}

control_valid :: proc(c: Control) -> bool {
	return c.intent[0] >= -1 && c.intent[0] <= 1 && c.intent[1] >= -1 && c.intent[1] <= 1 && own.sample_valid(c.player, rules()) && own.sample_valid(c.ball, rules())
}

state_valid :: proc(w: World) -> bool {
 if w.round==0 {return false}
	for name in w.names {if !lb.name_valid(name,false) {return false}}
	for player in w.players {if player.connected && !player.initialized {return false}}
	if w.minimum < 1 || w.minimum > SEATS || w.goals_to == 0 || w.won > 2 || w.left > w.goals_to || w.right > w.goals_to || !own.valid(w.ball, rules()) {return false}
	if w.ball.owner > SEATS || w.ball.pending.owner > SEATS || w.challenger > SEATS || w.ball.key.kind != 2 || w.ball.key.index != 0 || w.ball.changed_at > w.tick {return false}
	for player, i in w.players {if !own.valid(player.body, rules()) || player.body.owner != u16(i + 1) || player.body.key.kind != 1 || player.body.key.index != u32(i) || player.body.changed_at > w.tick || player.body.epoch != w.ball.epoch {return false}}
 for player in w.players {
  if player.stride_scope!=own.scope(player.body) {return false}
  pose:=player.body.value
  pose.position[0],pose.position[1]=player.stride_position[0],player.stride_position[1]
  if !rules().valid(nil,pose) {return false}
 }
	return true
}

model :: proc() -> net.Model(World, Control, Action, Event, SEATS) {
	return {control_timing = .Latest_Observation, step = step, reset_player = reset_player, action=action, action_valid=action_valid,
	        control_valid = control_valid, state_valid = state_valid, hold = proc(c: Control) -> Control {return c},
	        event_policy = proc(event: Event) -> v.Policy {return .Confirmed}}
}

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
	player := &w.players[seat - 1]
	player.initialized,player.named=true,false;w.names[seat-1]=lb.seat_name(seat)
	generation := player.body.key.generation
	if generation == max(u32) {r.abort(ctx); return}
	player.body = {}
	if own.init(&player.body, {1, u32(seat - 1), generation + 1}, ctx.epoch, ctx.tick, seat, spawn(seat), rules()) != .None {r.abort(ctx)}
 reset_stride(player)
}

emit :: proc(w: ^World, ctx: ^r.Step(Event), kind: Event_Kind, owner: u16 = 0) {
	r.emit(ctx, u64(w.round)<<32|100, u64(kind), Event{w.round,kind, owner, kind == .Offer ? w.ball.pending.revision : w.ball.revision, w.ball.value.position, {w.left, w.right}})
}

step :: proc(w: ^World, controls: [SEATS]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
	w.tick = ctx.tick
	for &player, i in w.players {
		if joins & (u64(1) << uint(i)) != 0 {if !player.initialized {reset_player(w,u16(i+1),ctx)};player.connected = true;reset_stride(&player)}
		if leaves & (u64(1) << uint(i)) != 0 {player.connected = false}
		if own.bind_epoch(&player.body, ctx.epoch, ctx.tick) != .None {r.abort(ctx); return}
  if player.stride_scope!=own.scope(player.body) {reset_stride(&player)}
		if w.started && player.connected && controls[i].player.sequence != 0 {
			result := own.accept(&player.body, u16(i + 1), controls[i].player, ctx.tick, rules())
			if result.error != .None {w.rejected += 1}
		}
	}
	if own.bind_epoch(&w.ball, ctx.epoch, ctx.tick) != .None {r.abort(ctx); return}
	count, first := 0, u16(0)
	for player, i in w.players {if player.connected {count += 1; if first == 0 {first = u16(i + 1)}}}
	if !w.started && !w.manual_start && count >= int(w.minimum) {
		w.started, w.kickoff_until = true, ctx.tick + KICKOFF_TICKS
		emit(w, ctx, .Started)
	}
	if w.ball.owner == 0 || !w.players[w.ball.owner - 1].connected {
		if first != w.ball.owner {own.cut(&w.ball, first, w.ball.value, ctx.tick, rules())}
	}
	if w.ball.pending.revision != 0 && !w.players[w.ball.pending.owner - 1].connected {own.cancel(&w.ball, ctx.tick)}
	own.expire(&w.ball, ctx.tick)
	if !w.started {return}
	// Current-owner samples precede candidates, so commit always wins the tick.
	previous_owner := w.ball.owner
	for pass in 0 ..< 2 {
		for control, i in controls {
			seat := u16(i + 1)
			if !w.players[i].connected || control.ball.sequence == 0 || (seat == previous_owner) != (pass == 0) {continue}
			result := own.accept(&w.ball, seat, control.ball, ctx.tick, rules())
			if result.error != .None {w.rejected += 1}
			if result.transferred {
				w.handoffs += 1; w.grant_after = ctx.tick + GRANT_TICKS; w.challenger = 0
				emit(w, ctx, .Handoff, seat)
			}
		}
	}
	if !w.started || w.won != 0 || ctx.tick < w.kickoff_until {return}
	ball := w.ball.value
	if ball.position[1] >= 130 && ball.position[1] <= 230 {
		scored := ball.position[0] < 6 ? u8(2) : ball.position[0] > 634 ? u8(1) : 0
		if scored != 0 {
			if scored == 1 {w.left += 1} else {w.right += 1}
			emit(w, ctx, .Goal, u16(scored))
			if w.left >= w.goals_to || w.right >= w.goals_to {w.won = scored; return}
			own.cut(&w.ball, first, own.Pose2{position = {320, 180}}, ctx.tick, rules())
			w.kickoff_until, w.challenger = ctx.tick + KICKOFF_TICKS, 0
			emit(w, ctx, .Reset)
			return
		}
	}
	if ctx.tick < w.grant_after || w.ball.pending.revision != 0 {return}
	best, best_distance, current_distance := u16(0), TOUCH_R * TOUCH_R, f32(1e9)
	for &player, i in w.players {
		if !player.connected {continue}
  position:=stride_position(player.body.value)
  moved:=abs(position[0]-player.stride_position[0])+abs(position[1]-player.stride_position[1])
  player.stride_position=position
		seat := u16(i + 1)
		distance := p.length_sq2(player.body.value.position - ball.position)
		if seat == w.ball.owner {current_distance = distance}
		moving := moved >= INTENT_STRIDE
		if !moving && seat != w.ball.owner {continue}
		if distance < best_distance {best, best_distance = seat, distance}
	}
	challenging := best != 0 && best != w.ball.owner && (current_distance > TOUCH_R * TOUCH_R || math.sqrt(best_distance) < math.sqrt(current_distance) - GRANT_EDGE)
	if !challenging {w.challenger = 0; return}
	if best != w.challenger {w.challenger, w.challenge_since = best, ctx.tick}
	hold := best_distance <= CONTACT_R * CONTACT_R ? CHALLENGE_TICKS / 3 : CHALLENGE_TICKS
	if p.length_sq2(ball.linear) <= BALL_SLOW * BALL_SLOW || ctx.tick - w.challenge_since >= hold {
		if own.offer(&w.ball, best, ctx.tick, 60) == .None {emit(w, ctx, .Offer, best)}
	}
}

leader :: proc(w:^World)->u16 {for player,i in w.players {if player.connected {return u16(i+1)}};return 0}
action_valid :: proc(a:Action)->bool {return int(a.start)+int(a.name.length>0)+int(a.restart_round>0)==1 && lb.name_valid(a.name)}
action :: proc(w:^World,seat:u16,a:Action,ctx:^r.Step(Event))->bool {
 if seat==0 || seat>SEATS || !w.players[seat-1].connected || !action_valid(a) {return false}
 if a.restart_round>0 {return restart(w,seat,a.restart_round,ctx)}
 if a.name.length>0 {w.names[seat-1]=a.name;w.players[seat-1].named=true;return true}
 if !w.manual_start || w.started || seat!=leader(w) {return false}
 count:=0;for player in w.players {if player.connected {count+=1}}
 if count<int(w.minimum) {return false}
 w.started,w.kickoff_until=true,ctx.tick+KICKOFF_TICKS;emit(w,ctx,.Started);return true
}

// Baseline is sampled only when ownership arbitration runs. Accepted pose values
// determine stride; requested controls and reported velocity are not substitutes.
stride_position :: proc(pose:own.Pose2)->[2]f32 {return {pose.position[0],pose.position[1]}}
reset_stride :: proc(player:^Player) {player.stride_scope=own.scope(player.body);player.stride_position=stride_position(player.body.value)}

// Keep the session/roster, but revoke all old body publication scopes. Build a
// candidate first so an exhausted revision cannot partially reset the match.
restart :: proc(w:^World,seat:u16,round:u32,ctx:^r.Step(Event))->bool {
 if w.won==0 || round!=w.round || round==max(u32) || seat!=leader(w) || ctx.tick>max(u64)-KICKOFF_TICKS {return false}
 count:=0;for player in w.players {if player.connected {count+=1}};if count<int(w.minimum) {return false}
 next:=w^
 for &player,i in next.players {
  if own.cut(&player.body,u16(i+1),spawn(u16(i+1)),ctx.tick,rules())!=.None {return false}
  reset_stride(&player)
 }
 if own.cut(&next.ball,seat,own.Pose2{position={320,180}},ctx.tick,rules())!=.None {return false}
 next.tick,next.round,next.started=ctx.tick,w.round+1,true
 next.left,next.right,next.won=0,0,0
 next.handoffs,next.rejected=0,0
 next.challenger,next.challenge_since,next.grant_after=0,0,0
 next.kickoff_until=ctx.tick+KICKOFF_TICKS
 w^=next;emit(w,ctx,.Started);return true
}
