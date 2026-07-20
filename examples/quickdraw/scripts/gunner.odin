//gd:extends Node2D
//gd:class Gunner
package quickdraw

// A GUNNER — one duelist, and the sim lane's reference entity. The struct IS
// the hybrid story in one screen:
//
//   x/y/vx/vy/aim/dash_cd  gd:"predict"  the CONTESTED state — the
//        server simulates it from inputs (gunner_tick below), your own screen
//        predicts it a few ticks ahead, everyone else's interpolates it. The
//        tick proc is single-player-looking; the netcode writes itself.
//   hp/pid/gold            gd:"replicate"          the DISCRETE state — the
//        coop kit's host-authoritative delta lane, unchanged, in the same
//        struct. Damage is adjudicated host-side and arrives as ordinary
//        deltas; the TRACER rides the tick's `fired` fact instead — the
//        mine-form gunner_tick_fx fires on every screen, each at its own
//        presentation time (yours at the muzzle instant, watchers when the
//        watch clock reaches the shot — ON the delayed barrel that fired it).
//
// The node half (gunner_process) dresses from the fields every frame, one
// line for everybody: after lane_present the fields hold presentation truth —
// your avatar is sim + glide, remote avatars are the watch-clock blend.

import "core:fmt"
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
	// TRIGGER lives here too: the cadence is a psim.Cool tagged `gd:"manual"`,
	// so gunner_tick drives its countdown itself (a dead gunner simply skips
	// the call) — still predicted through the embed, so your revolver answers
	// the click instantly and replays exactly. Movement stays hand-rolled: with
	// `manual` a block COULD now run mid-pipeline, but the dash is a locked-
	// velocity impulse, not psim.Mover's momentum intent — bespoke movement is
	// the honest fit here, a design choice, not a shelf limitation.
	x, y:    f32 `gd:"predict,interp"`,
	vx, vy:  f32 `gd:"predict"`,
	// interp=angle: watched gunners' aim GLIDES the short arc across ±π —
	// bare predict used to snap it per tick (the "stepped aim" that existed
	// only because a raw f32 lerp sweeps the long way around the circle).
	aim:     f32 `gd:"predict,interp=angle"`,
	dash_cd: u16 `gd:"predict"`,
	fire:    psim.Cool `gd:"manual"`, // driven below — so a dead gunner freezes it by not ticking it
	lob:     psim.Cool `gd:"manual"`, // the slow projectile's cadence (predicted, like the trigger)

	// The delta lane, beside it (host-authoritative, never resimmed).
	hp:   i32 `gd:"replicate"`,
	pid:  u8 `gd:"replicate"`,
	gold: u8 `gd:"replicate"`, // kill bounty — the shop's purse

	// The shop's effect: PREDICTED, so your boots answer the buy at your
	// next tick, not a round trip later. The buy itself is the verb below.
	gear: u8 `gd:"predict"`,

	// Local scratch — never on the wire.
	mine:      bool, // set by the census hook: my avatar
	painted:   bool,
	flash_ttl: f64,
	beam_ttl:  f64,
	hp_frame:  u64, // AUTHORITY: the _process frame its last hp write happened on (the edge-ordering probe)
}

// The hurt flash — the hp EDGE half. The session's per-frame pass hands every
// screen the NET change (the host's own adjudications included, zero role
// branches): no seen_* mirror to keep, no resync re-seed to forget, and a
// same-frame hit+heal that cancels never flashes. The decay and the dead tint
// stay continuous dressing in gunner_process below.
//
// AND IT IS THE ACID'S EDGE-ORDERING RECEIPT. A sim game's authority writes
// hp from INSIDE the sim tick (adjudicate_shot off gunner_tick_then, run_respawns
// off the authority world pass) — which is inside lane_frame, which runs AFTER
// session_tick has already made its own edge pass for the frame. Nothing then
// fires the pass again unless boot_pump does, so every hp edge on the host
// landed one whole frame behind the tick that caused it: a frame of full-hp,
// un-teleported host standing where the next tick's world can see it. Coop
// games never had it — their tick loop lives in the generated <snake>_step,
// which folds the pass in right after.
//
// The probe is the pair: the authority stamps g.frame where it writes hp, this
// half compares against the frame it is firing on. lag=0 is the fix (boot_pump's
// ksess.session_run_edges between lane_frame and lane_present); with that call
// removed every one of these prints lag=1 and the acid goes red. Clients are
// excluded on purpose — their hp arrives from the wire, a different path with
// nothing to be early or late about.
@(gd_half)
gunner_hp_edge :: proc(g: ^Quickdraw, self: ^Gunner, old, new: i32) {
	if new < old {
		self.flash_ttl = 0.25
	}
	if !g.ses.is_host || self.hp_frame == 0 {
		return // a client's wire-delivered edge, or a spawn-time baseline
	}
	lag := g.frame - self.hp_frame
	if lag == 0 {
		g.edge_same += 1
	} else {
		g.edge_late += 1
	}
	gd.print_str(fmt.tprintf("QD_EDGE hp=%d lag=%d same=%d late=%d", new, lag, g.edge_same, g.edge_late))
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
BTN_LOB :: u8(4)

// The sim-lane step: pure (predicted fields, input) → predicted fields, plus
// a returned PAYLOAD — the facts this tick learned. Runs authoritatively on
// the server, speculatively on your screen, and again in replays — the
// identical proc, which is the whole promise. The payload routes itself:
// `gunner_tick_then` fires on the AUTHORITY (the shot's consequence),
// `gunner_tick_fx` on this player's LIVE pass (the muzzle answer) — the
// generated thunk holds every role gate. No clocks, no nodes, no
// PhysicsServer: walls and crates are util.odin arithmetic.
@(gd_tick)
gunner_tick :: proc(self: ^Gunner, input: Gunner_Input) -> (fired: bool, lobbed: bool) {
	// Reading delta-lane hp here is a KNOWN mispredict source at the death
	// edge (the client learns you died ~a transit late, predicts a step the
	// server refused, and reconciles it back — the glide eats the pop). The
	// alternative is mirroring aliveness into the predict set; the honest
	// dependency reads better.
	if self.hp <= 0 {
		self.vx = 0
		self.vy = 0
		// Dead men hold the hammer: the cadences are `gd:"manual"`, so a dead
		// gunner just never reaches the cool_tick calls below — the cooldown
		// freezes with the body, no prepay arithmetic to cancel an auto-decrement.
		return
	}
	self.aim = angle_of(input.aim)

	// The trigger: hold to fan the hammer at the revolver's cadence. Pure
	// predicted state — psim.Cool's countdown gates locally with zero round
	// trips, and a replay re-derives the same shots from the same inputs.
	if input.buttons & BTN_FIRE != 0 && psim.ready(&self.fire, FIRE_CD) {
		fired = true
	}
	// The LOB: same predicted cadence, but its FACT spawns a slow projectile —
	// a client-predicted entity that leaves the muzzle this instant and the
	// authority's real one rekeys a round trip later (quickdraw.odin's halves).
	if input.buttons & BTN_LOB != 0 && psim.ready(&self.lob, LOB_CD) {
		lobbed = true
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

	// Drive the cadences — manual, so THIS is the decrement the auto-hoist used
	// to run after the tick. A `ready()` above re-armed to the interval this
	// same tick, so the next shot still lands exactly `interval` ticks later;
	// and the dead branch above returned before reaching here, freezing them.
	psim.cool_tick(&self.fire)
	psim.cool_tick(&self.lob)
	return
}

// THE BOUNTY SHOP — the tick-scheduled verb, showcased. Everything an input
// bit can't be: an ARGUMENT (which item), a VERDICT (an empty purse says
// no), a cross-lane read (gold, delta lane), and a predicted effect (gear —
// your boots answer at your next tick, ~15 ticks before the server's word
// returns at 240ms RTT). The generated `gunner_buy_cmd(&boot, gun, item)`
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

// The tracer, one proc for every screen: the mine-form gunner_tick_fx
// (quickdraw.odin) calls it — the shooter at the muzzle instant, watchers at
// the watch clock, so the beam leaves the barrel each screen is drawing.
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
	}

	// ONE line places everybody: after lane_present the fields are what this
	// frame should show — own avatar predicted + glided, the rest blended.
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
	gd.node2d_set_rotation(cast(gd.Node2d)self.gun, gd.Float(self.aim))

	if self.beam_ttl > 0 {
		self.beam_ttl -= delta
		if self.beam_ttl <= 0 {
			gd.set_bool(cast(gd.Object)self.beam, "visible", false)
		}
	}

	// The hurt flash (poked by gunner_hp_edge above) and the dead fade —
	// every screen, no messages, no hand-rolled hp mirror.
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
