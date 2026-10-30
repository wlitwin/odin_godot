package pitch

import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import lb "godot:replay/lobby"

SEATS :: 4
CONTENT :: u64(0x5253504545444234)
HZ :: 60
RUN_SPEED :: f32(2.2)
RUN_ACCEL :: f32(0.35)
KICK_REACH :: f32(30)
KICK_POWER :: f32(6.5)
KICK_CD :: u16(20)
SPIKE_REACH :: f32(44)
SPIKE_POWER :: f32(5.5)
KICKOFF_HOLD :: u16(72)
CENTER :: [2]f32{320, 180}
PLAYER_BOUNDS :: p.Aabb2{{21, 21}, {619, 339}}
BALL_LAW :: p.Roll_Law2{0.985, 9, 0.55, {{20, 20}, {620, 340}}}
SPAWNS :: [4][2]f32{{200, 100}, {440, 260}, {200, 260}, {440, 100}}
KICK :: u8(1)

Player :: struct {initialized, connected, named: bool, motion: p.Motion2, kick_cd: u16, team: u8}
Ball :: struct {motion: p.Motion2, hold: u16, reset: u32}
Score :: struct {left, right, winner: u8}
World :: struct {
	players: [SEATS]Player,
	names: [SEATS]lb.Name,
	manual_start: bool,
	ball: Ball,
	score: Score,
	clock: u64,
	round: u32,
	kicks, spikes, contacts: u32,
	started: bool,
	min_players, goals_to, seat_offset: u8,
}
Controls :: struct {move: [2]i8, buttons: u8}
Action :: struct {spike, start: bool, name: lb.Name, restart_round: u32}
Event_Kind :: enum u8 {Kick, Spike, Goal}
Event :: struct {kind: Event_Kind, seat, team: u8, position, velocity: [2]f32, score: Score}

initial :: proc(dedicated := false, min_players: u8 = 1, goals_to: u8 = 3, manual_start: bool = false) -> World {
	w := World{round=1,manual_start=manual_start,ball = {motion = {position = CENTER}, hold = KICKOFF_HOLD}, min_players = min_players, goals_to = goals_to, seat_offset = dedicated ? 1 : 0}
	for &name,i in w.names {name=lb.seat_name(u16(i+1))}
	return w
}

model :: proc() -> net.Model(World, Controls, Action, Event, SEATS) {
	return {step = step, action = action, reset_player = reset_player, control_valid = control_valid, state_valid = state_valid,
	        action_valid = action_valid, hold = proc(c: Controls) -> Controls {return c},
	        event_owner = proc(e: Event) -> u16 {return u16(e.seat)}}
}

control_valid :: proc(c: Controls) -> bool {return c.move[0] >= -1 && c.move[0] <= 1 && c.move[1] >= -1 && c.move[1] <= 1 && c.buttons & ~KICK == 0}
state_valid :: proc(w: World) -> bool {
	for name in w.names {if !lb.name_valid(name,false) {return false}}
	if w.round==0 {return false}
	if w.manual_start && w.seat_offset!=0 {return false}
	if w.min_players < 1 || w.min_players > SEATS || w.goals_to < 1 || w.seat_offset > 1 || w.ball.hold > KICKOFF_HOLD || w.score.winner > 2 {return false}
	if w.score.left > w.goals_to || w.score.right > w.goals_to {return false}
	if (w.score.winner == 1) != (w.score.left == w.goals_to) || (w.score.winner == 2) != (w.score.right == w.goals_to) {return false}
	if w.ball.reset != u32(w.score.left) + u32(w.score.right) {return false}
	for player, i in w.players {
		team := (i + 1 + int(w.seat_offset)) % 2 == 1 ? u8(1) : u8(2)
		if player.kick_cd > KICK_CD || (player.connected && !player.initialized) || (player.initialized && player.team != team) {return false}
	}
	return true
}

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
	w.names[seat-1]=lb.seat_name(seat)
	pid := int(seat) + int(w.seat_offset)
	spots := SPAWNS
	w.players[seat - 1] = {initialized = true, connected = true, motion = {position = spots[pid % len(spots)]}, team = pid % 2 == 1 ? 1 : 2}
}

action_valid :: proc(a:Action)->bool {
 count:=int(a.spike)+int(a.start)+int(a.name.length>0)+int(a.restart_round>0)
 return count==1 && lb.name_valid(a.name)
}
action :: proc(w:^World,seat:u16,a:Action,ctx:^r.Step(Event))->bool {
 if seat==0 || seat>SEATS || !action_valid(a) || !w.players[seat-1].connected {return false}
 if a.restart_round>0 {return restart(w,seat,a.restart_round,ctx)}
 if a.spike {return spike(w,seat,a,ctx)}
 if a.name.length>0 {w.names[seat-1]=a.name;w.players[seat-1].named=true;return true}
 if !w.manual_start || w.started || seat!=leader(w^) {return false}
 count:=0;for p in w.players {if p.connected {count+=1}}
 if count<int(w.min_players) {return false}
 w.started=true;return true
}

// Match leadership is a deterministic roster policy, distinct from transport
// authority. Planned handoff preserves a connected leader; loss selects the
// first surviving seat without a role-dependent simulation branch.
leader :: proc(w:World)->u16 {
 for player,i in w.players {if player.connected {return u16(i+1)}}
 return 0
}

// A new match is an authored command in the same session, so roster identity,
// command sequencing and network authority survive. Old-round requests cannot
// restart a later completed match.
restart :: proc(w:^World,seat:u16,round:u32,ctx:^r.Step(Event))->bool {
 if w.score.winner==0 || seat!=leader(w^) || round!=w.round || round==max(u32) {return false}
 count:=0;for player in w.players {if player.connected {count+=1}}
 if count<int(w.min_players) {return false}
 names,players:=w.names,w.players
 next:=initial(w.seat_offset==1,w.min_players,w.goals_to,w.manual_start)
 next.clock,next.round,next.started=w.clock,w.round+1,true
 for player,i in players {if player.initialized {
  reset_player(&next,u16(i+1),ctx)
  next.players[i].connected,next.players[i].named=player.connected,player.named
 }}
 next.names=names;w^=next;return true
}
