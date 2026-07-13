package cavecrawl_scripts

// Peer-owned projectile visuals — the zero-felt-lag machinery. Press fire and
// YOUR screen's rock flies this frame; the host's authoritative rock (the
// only kind that hurts, see host.odin) flies a beat later and announces the
// cast so every OTHER screen draws it too. The flying/reaping/contact
// mechanics live in kit/fx's tracer pool; this file keeps what is the CAVE's:
// where a rock comes from (rock_fire), who it may hit (rock_targets), and
// what an impact means (rock_impact — the predicted hp dip through the
// kcombat.Predicted_Hp overlay, sparks, flash, hud; truth arrives as
// ordinary deltas and squares the number).

import gd "godot:godot"
import kboot "godot:kit/boot"
import kcombat "godot:kit/combat"
import kfx "godot:kit/fx"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"
import "core:math"

rock_fire :: proc(shooter: knet.Player_Id, origin: [2]f32, aim: [2]f32) -> (f: kcombat.Fire, ok: bool) {
	dx, dy := aim.x, aim.y
	n := math.sqrt(dx * dx + dy * dy)
	if n == 0 {return}
	return kcombat.Fire {
			shooter = shooter,
			// The cast's OWN origin (owner truth, leashed in spelunker_throw,
			// returned as the verb's payload) — NOT the host's lagged copy of
			// the shooter: the authoritative rock must fly the same line the
			// shooter's screen saw hit.
			origin  = {origin.x, origin.y, 0},
			vel     = {dx / n * ROCK_SPEED, dy / n * ROCK_SPEED, 0},
			ttl     = ROCK_TTL,
			kind    = FIRE_ROCK,
		},
		true
}

// A rock on THIS screen: a ● tracer in the kit/fx pool (no entity, no wire).
add_visual_rock :: proc(self: ^CaveLobby, f: kcombat.Fire) {
	kfx.tracer_add(&self.tracers, self.boot.world, f, "\xE2\x97\x8F", ksess.session_tick_hz(&self.ses))
}

// Host: a confirmed throw (spelunker_throw_then) launches the AUTHORITATIVE
// rock (the only kind that hurts), shows the host its own visual, and
// announces the fire so every other peer draws theirs. The shooter's visual
// already flew at cast time — it skips its own announcement.
cave_launch_rock :: proc(self: ^CaveLobby, shooter: knet.Player_Id, origin: [2]f32, aim: [2]f32) {
	f, ok := rock_fire(shooter, origin, aim)
	if !ok {return}
	append(&self.flying, Cave_Rock{p = kcombat.Projectile{pos = f.origin, vel = f.vel, left = f.ttl}, shooter = shooter})
	if shooter != self.ses.me {
		add_visual_rock(self, f) // the host's screen (its own casts drew at cast time)
	}
	kcombat.fire_announce(&self.ses, TAG_FIRE, f)
}

// Every peer: somebody ELSE's rock (kcombat.fire_listen already dropped the
// host's own copy, my echo, and anything a non-host tried to author).
cave_on_fire :: proc(user: rawptr, f: kcombat.Fire) {
	self := cast(^CaveLobby)user
	add_visual_rock(self, f)
}

// Every peer, once per FRAME: kit/fx flies my screen's rocks and sweeps the
// same segments the host's tick sim does, just finer — contact lands on the
// frame the crossing happens, never after the authority's tick.
cave_visual_frame :: proc(self: ^CaveLobby, delta: f64) {
	kfx.tracers_frame(&self.tracers, delta, self, rock_targets, rock_impact)
}

// Who a shooter's rock may hit right now: everybody alive except the
// shooter's own avatar.
rock_targets :: proc(user: rawptr, shooter: knet.Player_Id) -> []kcombat.Target {
	self := cast(^CaveLobby)user
	targets := make([dynamic]kcombat.Target, context.temp_allocator)
	for id, sp in self.spelunkers {
		if id == self.avatar_of[shooter] || sp.hp <= 0 {continue}
		append(&targets, kcombat.Target{id = u32(id), pos = {sp.x, sp.y, 0}, radius = BODY_RADIUS})
	}
	for id, dw in self.dwellers {
		if dw.hp > 0 {
			append(&targets, kcombat.Target{id = u32(id), pos = {dw.x, dw.y, 0}, radius = BODY_RADIUS})
		}
	}
	return targets[:]
}

// The impact you SEE is the impact you feel: a predicted hp dip (overlay,
// never the replicated field), sparks at the victim, a red flash tweening
// back — same frame as visual contact, no round trip. If the host saw a
// miss, the dip heals back when truth lands.
rock_impact :: proc(user: rawptr, hit: kfx.Tracer_Hit) {
	self := cast(^CaveLobby)user
	now := now_s()
	truth, view: i32
	if victim, is_sp := self.spelunkers[knet.Net_Id(hit.target)]; is_sp {
		truth = victim.hp
		kcombat.php_note_hit(&victim.php, victim.hp, ROCK_DMG, now)
		view = kcombat.php_display(&victim.php, victim.hp, now)
	} else if dw, is_dw := self.dwellers[knet.Net_Id(hit.target)]; is_dw {
		truth = dw.hp
		kcombat.php_note_hit(&dw.php, dw.hp, ROCK_DMG, now)
		view = kcombat.php_display(&dw.php, dw.hp, now)
	}
	fx_burst_at(self, hit.pos.x, hit.pos.y, {1, 0.9, 0.4, 1})
	victim_node, _ := kboot.boot_node(&self.boot, knet.Net_Id(hit.target))
	fx_flash(victim_node, {1, 0.35, 0.35, 1})
	refresh_hud(self)
	gd.print_str(fmt.tprintf("CAVE_IMPACT mine=%v view=%d truth=%d", hit.shooter == self.ses.me, view, truth))
}
