package cavecrawl_scripts

// Peer-owned projectile visuals — the zero-felt-lag machinery. Press fire and
// YOUR screen's rock flies this frame; the host's authoritative rock (the
// only kind that hurts, see host.odin) flies a beat later and announces the
// cast so every OTHER screen draws it too. Impacts seen locally dip hp
// through the kcombat.Predicted_Hp overlay; truth arrives as ordinary deltas
// and squares the number.

import gd "godot:godot"
import kcombat "godot:kit/combat"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:fmt"
import "core:math"

rock_fire :: proc(shooter: knet.Player_Id, sp: ^Spelunker) -> (f: kcombat.Fire, ok: bool) {
	dx, dy := sp.aim.x, sp.aim.y
	n := math.sqrt(dx * dx + dy * dy)
	if n == 0 {return}
	return kcombat.Fire {
			shooter = shooter,
			origin  = {sp.x, sp.y, 0},
			vel     = {dx / n * ROCK_SPEED, dy / n * ROCK_SPEED, 0},
			ttl     = ROCK_TTL,
			kind    = FIRE_ROCK,
		},
		true
}

// A rock on THIS screen: a plain Label (no entity, no wire). The Fire's
// px/tick velocity and tick ttl become px/s and seconds here — visuals
// live on the frame clock.
add_visual_rock :: proc(self: ^CaveLobby, f: kcombat.Fire) {
	node := gd.new_label()
	gd.set_string(cast(gd.Object)node, "text", "\xE2\x97\x8F") // ●
	gd.add_child(self.world, cast(gd.Node)node)
	gd.control_set_position(cast(gd.Control)node, {f.origin.x, f.origin.y}, false)
	hz := f32(knet.DEFAULT_TICK_HZ)
	append(&self.visuals, Visual_Rock {
		pos = f.origin,
		vel = f.vel * hz,
		left = f32(f.ttl) / hz,
		shooter = f.shooter,
		node = node,
	})
}

// Host: a confirmed throw launches the AUTHORITATIVE rock (the only kind
// that hurts), shows the host its own visual, and announces the fire so
// every other peer draws theirs. The shooter's visual already flew at cast
// time — it skips its own announcement.
cave_launch_rock :: proc(self: ^CaveLobby, shooter: knet.Player_Id, sp: ^Spelunker) {
	f, ok := rock_fire(shooter, sp)
	if !ok {return}
	append(&self.flying, Cave_Rock{p = kcombat.Projectile{pos = f.origin, vel = f.vel, left = f.ttl}, shooter = shooter})
	if shooter != self.ses.me {
		add_visual_rock(self, f) // the host's screen (its own casts drew at cast time)
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	kcombat.fire_write(&w, f)
	ksess.session_app_send(&self.ses, ksess.BROADCAST_PEER, TAG_FIRE, knet.writer_bytes(&w))
}

// Every peer: a fire announcement — draw the rock, unless it's my own echo
// (mine flew at cast time). Only the host authors these.
cave_on_fire :: proc(user: rawptr, from: knet.Player_Id, from_peer: int, r: ^knet.Reader) {
	self := cast(^CaveLobby)user
	if self.ses.is_host || from_peer != ksess.HOST_PEER {return}
	f, ok := kcombat.fire_read(r)
	if !ok || f.shooter == self.ses.me {return}
	add_visual_rock(self, f)
}

// Every peer, once per FRAME: fly MY screen's rocks and, on visual contact
// with a body, play the impact NOW — a predicted hp dip (overlay, never the
// replicated field) and the effect. Truth arrives a beat later and squares
// the number; if the host saw a miss, the dip heals back. Frame stepping
// sweeps the same segments the host's tick sim does, just finer — contact
// lands on the frame the crossing happens, never after the authority's tick.
cave_visual_frame :: proc(self: ^CaveLobby, delta: f64) {
	now := now_s()
	dt := f32(delta)
	for i := 0; i < len(self.visuals); {
		v := &self.visuals[i]
		from := v.pos
		step_vel := v.vel * dt
		v.pos += step_vel
		v.left -= dt
		gd.control_set_position(cast(gd.Control)v.node, {v.pos.x, v.pos.y}, false)

		targets := make([dynamic]kcombat.Target, context.temp_allocator)
		for id, sp in self.spelunkers {
			if id == self.avatar_of[v.shooter] || sp.hp <= 0 {continue}
			append(&targets, kcombat.Target{id = u32(id), pos = {sp.x, sp.y, 0}, radius = BODY_RADIUS})
		}
		for id, dw in self.dwellers {
			if dw.hp > 0 {
				append(&targets, kcombat.Target{id = u32(id), pos = {dw.x, dw.y, 0}, radius = BODY_RADIUS})
			}
		}
		if hit, hit_ok := kcombat.projectile_hit(from, step_vel, targets[:]); hit_ok {
			truth, view: i32
			if victim, is_sp := self.spelunkers[knet.Net_Id(hit.id)]; is_sp {
				truth = victim.hp
				kcombat.php_note_hit(&victim.php, victim.hp, ROCK_DMG, now)
				view = kcombat.php_display(&victim.php, victim.hp, now)
			} else if dw, is_dw := self.dwellers[knet.Net_Id(hit.id)]; is_dw {
				truth = dw.hp
				kcombat.php_note_hit(&dw.php, dw.hp, ROCK_DMG, now)
				view = kcombat.php_display(&dw.php, dw.hp, now)
			}
			// The impact you SEE is the impact you feel: sparks at the
			// contact point, a red flash tweening back on the victim —
			// same frame as the predicted hp dip, no round trip.
			fx_burst_at(self, hit.pos.x, hit.pos.y, {1, 0.9, 0.4, 1})
			fx_flash(self.nodes[knet.Net_Id(hit.id)], {1, 0.35, 0.35, 1})
			refresh_hud(self)
			gd.print_str(fmt.tprintf("CAVE_IMPACT mine=%v view=%d truth=%d", v.shooter == self.ses.me, view, truth))
			gd.node_queue_free(cast(gd.Node)v.node)
			unordered_remove(&self.visuals, i)
			continue
		}
		if v.left <= 0 {
			gd.node_queue_free(cast(gd.Node)v.node)
			unordered_remove(&self.visuals, i)
			continue
		}
		i += 1
	}
}
