package duel

import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import h "godot:replay/history"
import net "godot:replay/net"
import lb "godot:replay/lobby"

CONTENT :: u64(0x52515549434b4432)
SEATS :: 4
HZ :: u32(60)
RUN_SPEED :: f32(2.2)
DASH_SPEED :: f32(7)
DASH_CD :: u16(45)
DASH_LEN :: u16(8)
FIRE_CD :: u16(18)
LOB_CD :: u16(48)
LOB_LIFE :: u16(70)
BODY_RADIUS :: f32(9)
FIRE :: u8(1)
DASH :: u8(2)
LOB :: u8(4)
CRATES :: [2]p.Aabb2{{{180, 70}, {230, 150}}, {{410, 70}, {460, 150}}}
SPAWNS :: [4][2]f32{{60, 60}, {580, 60}, {60, 300}, {580, 300}}

Player :: struct {
	initialized, connected: bool,
	position, velocity, drone: [2]f32,
	aim, dash_cd, fire_cd, lob_cd: u16,
	hp: i32,
	gold: u8,
	boots: bool,
	respawn_at: u64,
	kills, deaths, life: u32,
}
Bullet :: struct {key: u64, position, velocity: [2]f32, life: u16, owner: u8}
World :: struct {
	names: [SEATS]lb.Name,
	started, manual_start: bool,
	players: [SEATS]Player,
	bullets: r.Pool(Bullet, 64),
	history: h.History([SEATS]p.Hurtbox2, 32),
	clock: u64,
	shots, hits, lobs, lands, buys, expired_queries: u32,
	rewind: bool,
	spawn_offset: u8,
	starting_gold: u8,
}
Controls :: struct {move, drone: [2]i8, aim: u16, buttons: u8}
Action :: struct {item: u8, name: lb.Name, start: bool}
Event_Kind :: enum u8 {Shot, Hit, Killed, Respawned, Lobbed, Landed, Bought}
Event :: struct {kind: Event_Kind, seat, target: u8, position: [2]f32, aim: u16, key, judged_tick: u64, query: net.View_Status}

initial :: proc(rewind: bool = true, dedicated: bool = false, gold: u8 = 0, manual_start: bool = false) -> World {return {rewind = rewind, spawn_offset = dedicated ? 1 : 0, starting_gold = gold, started = !manual_start, manual_start = manual_start}}
spawn :: proc(w: ^World, seat: u16) -> [2]f32 {spots := SPAWNS; return spots[(int(seat) + int(w.spawn_offset)) % len(spots)]}
angle :: proc(value: u16) -> f32 {return f32(value) * (2 * math.PI / 65536)}
aim :: proc(value: f32) -> u16 {turn := value / (2 * math.PI); turn -= math.floor(turn); return u16(turn * 65536)}
direction :: proc(value: u16) -> [2]f32 {a := angle(value); return {math.cos(a), math.sin(a)}}
normalize :: proc(v: [2]f32) -> [2]f32 {length := math.sqrt(v[0] * v[0] + v[1] * v[1]); return length <= 0.00001 ? [2]f32{} : v / length}

model :: proc() -> net.Model(World, Controls, Action, Event, SEATS) {
	return {step_view = step, action = buy, reset_player = reset_player, control_valid = control_valid,
	        action_valid = action_valid, state_valid = state_valid,
	        hold = proc(c: Controls) -> Controls {return c}, event_owner = proc(e: Event) -> u16 {return u16(e.kind == .Hit || e.kind == .Killed ? e.target : e.seat)}}
}
control_valid :: proc(c: Controls) -> bool {
	return c.move[0] >= -1 && c.move[0] <= 1 && c.move[1] >= -1 && c.move[1] <= 1 &&
	       c.drone[0] >= -1 && c.drone[0] <= 1 && c.drone[1] >= -1 && c.drone[1] <= 1 && c.buttons & ~u8(7) == 0
}
state_valid :: proc(w: World) -> bool {
	if w.spawn_offset > 1 || (!w.manual_start && !w.started) {return false}
	for name in w.names {if !lb.name_valid(name) {return false}}
	for player in w.players {
		if player.hp < 0 || player.hp > 3 || (player.initialized && player.life == 0) ||
		   player.dash_cd > DASH_CD || player.fire_cd > FIRE_CD || player.lob_cd > LOB_CD {return false}
	}
	count := u32(0)
	for bullet, i in w.bullets.values {if w.bullets.alive[i] {count += 1; if bullet.key == 0 || bullet.owner < 1 || bullet.owner > SEATS || bullet.life == 0 || bullet.life > LOB_LIFE || w.bullets.generations[i] == 0 {return false}}}
	return count == w.bullets.count
}

leader :: proc(w: ^World) -> u16 {
 for player,i in w.players {if player.connected {return u16(i+1)}}
 return 0
}
action_valid :: proc(a: Action) -> bool {
 if !lb.name_valid(a.name) || a.item>1 {return false}
 return int(a.item==1)+int(a.name.length>0)+int(a.start)==1
}
