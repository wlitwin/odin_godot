//gd:extends Node2D
//gd:class Gunner
package quickdraw

// A GUNNER — one duelist, and the sim lane's reference entity. The struct IS
// the hybrid story in one screen:
//
//   x/y/vx/vy/aim/dash_cd  gd:"replicate,predict"  the CONTESTED state — the
//        server simulates it from inputs (gunner_tick below), your own screen
//        predicts it a few ticks ahead, everyone else's interpolates it. The
//        tick proc is single-player-looking; the netcode writes itself.
//   hp/pid/shot_seq/shot_aim  gd:"replicate"       the DISCRETE state — the
//        coop kit's host-authoritative delta lane, unchanged, in the same
//        struct. Damage is adjudicated host-side and arrives as ordinary
//        deltas; tracers are drawn from the shot_seq EDGE on every screen
//        (state, not events — the byte outlives the tick).
//
// The node half (gunner_process) dresses from the fields every frame, one
// line for everybody: after lane_present the fields hold presentation truth —
// your avatar is sim + glide, remote avatars are the watch-clock blend.

import gd "godot:godot"
import knet "godot:kit/net"
import psim "godot:play/sim"

Gunner :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	gun:    gd.Polygon2d `gd:"onready=Gun"`,
	beam:   gd.Polygon2d `gd:"onready=Beam"`,
	net_id: knet.Net_Id,

	// The sim lane (server-simulated, client-predicted, reconciled). The
	// TRIGGER lives here too: the cadence is a psim.Cool, its countdown
	// predicted through the embed, so your revolver answers the click
	// instantly and replays exactly. (Movement stays hand-rolled: the crate
	// pushout runs mid-pipeline — after the clamp, before the shot's
	// adjudication — where a block tick, which runs after this whole proc,
	// can't reach.)
	x, y:    f32 `gd:"replicate,predict,interp"`,
	vx, vy:  f32 `gd:"replicate,predict"`,
	aim:     f32 `gd:"replicate,predict"`,
	dash_cd: u16 `gd:"replicate,predict"`,
	fire:    psim.Cool,

	// The delta lane, beside it (host-authoritative, never resimmed).
	hp:       i32 `gd:"replicate"`,
	pid:      u8 `gd:"replicate"`,
	shot_seq: u8 `gd:"replicate"`, // bumps per adjudicated shot — the tracer edge
	shot_aim: f32 `gd:"replicate"`,
	gold:     u8 `gd:"replicate"`, // kill bounty — the shop's purse

	// The shop's effect: PREDICTED, so your boots answer the buy at your
	// next tick, not a round trip later. The buy itself is the verb below.
	gear: u8 `gd:"replicate,predict"`,

	// Local scratch — never on the wire.
	mine:      bool, // set by the census hook: my avatar
	painted:   bool,
	seen_shot: u8, // tracer edge (remote shots)
	seen_hp:   i32, // hurt-flash edge
	flash_ttl: f64,
	beam_ttl:  f64,
}

// Sampled once per predicted tick (quickdraw.odin's qd_sample); discovered by
// scriptgen from the tick proc's signature. POD, ~6 bytes, redundant on the
// wire — the whole upstream bandwidth of a player.
Gunner_Input :: struct {
	move:    [2]i8, // -1/0/1 per axis
	aim:     u16, // turn fraction (util.odin angle codecs)
	buttons: u8,
}

BTN_FIRE :: u8(1)
BTN_DASH :: u8(2)

// The sim-lane step: pure (predicted fields, input) → predicted fields, plus
// a returned PAYLOAD — the facts this tick learned. Runs authoritatively on
// the server, speculatively on your screen, and again in replays — the
// identical proc, which is the whole promise. The payload routes itself:
// `gunner_tick_then` fires on the AUTHORITY (the shot's consequence),
// `gunner_tick_fx` on this player's LIVE pass (the muzzle answer) — the
// generated thunk holds every role gate. No clocks, no nodes, no
// PhysicsServer: walls and crates are util.odin arithmetic.
@(gd_tick)
gunner_tick :: proc(self: ^Gunner, input: Gunner_Input) -> (fired: bool) {
	// Reading delta-lane hp here is a KNOWN mispredict source at the death
	// edge (the client learns you died ~a transit late, predicts a step the
	// server refused, and reconciles it back — the glide eats the pop). The
	// alternative is mirroring aliveness into the predict set; the honest
	// dependency reads better.
	if self.hp <= 0 {
		self.vx = 0
		self.vy = 0
		// Dead men hold the hammer: the Cool block's decrement still runs
		// after this return, so prepay it — the cooldown freezes with the
		// body, exactly as the hand-rolled early return froze it.
		if self.fire.left > 0 {
			self.fire.left += 1
		}
		return false
	}
	self.aim = angle_of(input.aim)

	// The trigger: hold to fan the hammer at the revolver's cadence. Pure
	// predicted state — psim.Cool's countdown gates locally with zero round
	// trips, and a replay re-derives the same shots from the same inputs.
	if input.buttons & BTN_FIRE != 0 && psim.ready(&self.fire, FIRE_CD) {
		fired = true
	}

	// The boots the shop sold you — predicted state read by the predicted
	// sim, so the speed answers the buy on YOUR timeline.
	speed := self.gear == GEAR_BOOTS ? RUN_SPEED * 1.3 : RUN_SPEED

	dashing := self.dash_cd > DASH_CD - DASH_LEN
	if !dashing {
		dir := normalized({f32(input.move[0]), f32(input.move[1])})
		self.vx = dir.x * speed
		self.vy = dir.y * speed
		if input.buttons & BTN_DASH != 0 && self.dash_cd == 0 && (dir.x != 0 || dir.y != 0) {
			// The dash is the twitch-feel demo: an impulse your screen takes
			// THIS tick, at any latency — locked to its start direction.
			self.vx = dir.x * DASH_SPEED
			self.vy = dir.y * DASH_SPEED
			self.dash_cd = DASH_CD
		}
	}
	if self.dash_cd > 0 {
		self.dash_cd -= 1
	}

	self.x += self.vx
	self.y += self.vy
	self.x = clamp(self.x, ARENA_WALL + GUN_R, ARENA_W - ARENA_WALL - GUN_R)
	self.y = clamp(self.y, ARENA_WALL + GUN_R, ARENA_H - ARENA_WALL - GUN_R)
	for c in CRATES {
		crate_pushout(&self.x, &self.y, c)
	}
	return
}

// THE BOUNTY SHOP — the tick-scheduled verb, showcased. Everything an input
// bit can't be: an ARGUMENT (which item), a VERDICT (an empty purse says
// no), a cross-lane read (gold, delta lane), and a predicted effect (gear —
// your boots answer at your next tick, ~15 ticks before the server's word
// returns at 240ms RTT). The generated `gunner_buy_cmd(&lane, gun, item)`
// schedules it; a rejection unwinds the gold and the reconcile scrubs the
// gear, the same glide as any mispredict.
GEAR_BOOTS :: u8(1)
BOOTS_PRICE :: u8(1)

@(gd_command)
gunner_buy :: proc(self: ^Gunner, item: u8) -> bool {
	if item != GEAR_BOOTS || self.gear == item {return false}
	if self.gold < BOOTS_PRICE {return false}
	self.gold -= BOOTS_PRICE
	self.gear = item
	return true
}

// The muzzle answer: shooter-local, instant, presentation-only (quickdraw.odin
// calls it off the live input edge; remote screens draw off the shot_seq edge).
gunner_beam :: proc(self: ^Gunner, a: f32) {
	length := shot_wall_limit(self.x, self.y, a)
	gd.node2d_set_rotation(cast(gd.Node2d)self.beam, gd.Float(a))
	gd.node2d_set_scale(cast(gd.Node2d)self.beam, {length / 100.0, 1})
	gd.set_bool(cast(gd.Object)self.beam, "visible", true)
	self.beam_ttl = 0.09
}

gunner_process :: proc(self: ^Gunner, delta: f64) {
	if !self.painted && self.pid != 0 {
		self.painted = true
		gd.polygon2d_set_color(self.skin, peer_color(int(self.pid)))
		self.seen_hp = self.hp
		self.seen_shot = self.shot_seq
	}

	// ONE line places everybody: after lane_present the fields are what this
	// frame should show — own avatar predicted + glided, the rest blended.
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
	gd.node2d_set_rotation(cast(gd.Node2d)self.gun, gd.Float(self.aim))

	// Remote shots: the tracer rides the shot_seq EDGE (mine already flashed
	// at the muzzle, live — skip the echo).
	if self.shot_seq != self.seen_shot {
		self.seen_shot = self.shot_seq
		if !self.mine {
			gunner_beam(self, self.shot_aim)
		}
	}
	if self.beam_ttl > 0 {
		self.beam_ttl -= delta
		if self.beam_ttl <= 0 {
			gd.set_bool(cast(gd.Object)self.beam, "visible", false)
		}
	}

	// Hurt flash + the dead fade, from hp deltas — every screen, no messages.
	if self.hp != self.seen_hp {
		if self.hp < self.seen_hp {
			self.flash_ttl = 0.25
		}
		self.seen_hp = self.hp
	}
	if self.flash_ttl > 0 {
		self.flash_ttl -= delta
		gd.polygon2d_set_color(self.skin, {1, 0.25, 0.2, 1})
		if self.flash_ttl <= 0 {
			self.painted = false // repaint the seat color next frame
		}
	} else if self.hp <= 0 {
		gd.polygon2d_set_color(self.skin, {0.35, 0.32, 0.3, 0.55})
		self.painted = false
	}
}
