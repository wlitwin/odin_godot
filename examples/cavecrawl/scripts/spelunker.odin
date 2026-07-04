//gd:extends Label
//gd:class Spelunker
package cavecrawl_scripts

// A player's avatar — THE toolkit author surface for a multiplayer entity:
// tag the fields, done. x/y are owner-streamed (whoever owns this spelunker
// writes them; everyone else sees interpolated motion), the bag replicates
// to everyone (co-op transparency: you can see what your friends carry),
// and phase 4 adds the combat block: hp, stamina, ability cooldowns, status
// effects — all plain replicated POD the host decays and deltas carry.
// The node IS its own visual (a Label glyph); process just places it.

import gd "godot:godot"
import kcombat "godot:kit/combat"
import kitems "godot:kit/items"
import knet "godot:kit/net"

Spelunker :: struct {
	owner:     gd.Label,
	net_id:    knet.Net_Id, // assigned by the session at spawn
	x, y:      f32 `gd:"replicate,interp,owner"`,
	bag:       [6]kitems.Slot `gd:"replicate"`,
	hp:        i32 `gd:"replicate"`,
	stamina:   i32 `gd:"replicate"`,
	cds:       [2]u16 `gd:"replicate"`, // ability cooldowns, host-decayed
	fx:        [2]kcombat.Effect `gd:"replicate"`, // status effects, host-decayed
	last_drop: kitems.Slot, // scratch for the drop hook — never on the wire
	aim:       [2]f32, // scratch for the throw hook — never on the wire
	php:       kcombat.Predicted_Hp, // scratch: impacts SEEN here, pre-truth
	was_dead:  bool, // scratch: death-edge detector for the pyre burst
	pyre:      gd.Cpu_Particles2d, // scratch: this corpse's own death particles
}

// Drop a bag slot at my feet: my bag empties on my screen this frame; the
// host's drop hook mints the Pickup entity everyone sees.
@(gd_command = "predict")
spelunker_drop :: proc(self: ^Spelunker, slot: i32) -> bool {
	if self.hp <= 0 {return false} // the dead drop everything on their own
	dropped := kitems.take(self.bag[:], int(slot), max(u16))
	if dropped.count == 0 {return false}
	self.last_drop = dropped
	return true
}

// Throw a rock: the WHOLE cast, zero role branches. The gate (alive +
// cooldown + stamina) bites instantly on the thrower's screen and refuses
// identically on the host; the host's hook launches the authoritative rock.
@(gd_command = "predict")
spelunker_throw :: proc(self: ^Spelunker, dx: f32, dy: f32) -> bool {
	if self.hp <= 0 {return false}
	if dx == 0 && dy == 0 {return false}
	if !kcombat.ability_try(self.cds[:], 0, ROCK_ABILITY, &self.stamina) {return false}
	self.aim = {dx, dy}
	return true
}

// Bandage up: the second ability slot. Self-targeted, so this command IS
// the whole effect — no host hook half at all: the same proc heals
// instantly on the caster's screen and re-runs authoritatively on the host.
@(gd_command = "predict")
spelunker_heal :: proc(self: ^Spelunker) -> bool {
	if self.hp <= 0 || self.hp >= MAX_HP {return false} // corpses and the hale need no bandage
	if !kcombat.ability_try(self.cds[:], 1, HEAL_ABILITY, &self.stamina) {return false}
	self.hp = min(self.hp + HEAL_AMOUNT, MAX_HP)
	return true
}

spelunker_ready :: proc(self: ^Spelunker) {
	gd.set_string(cast(gd.Object)self.owner, "text", "\xE2\x9B\x8F") // ⛏
}

spelunker_process :: proc(self: ^Spelunker, delta: f64) {
	gd.control_set_position(cast(gd.Control)self.owner, {self.x, self.y}, false)
	// Everyone can see who's dead — the corpse glyph replicates with hp.
	gd.set_string(cast(gd.Object)self.owner, "text", self.hp > 0 ? "\xE2\x9B\x8F" : "\xF0\x9F\x92\x80") // ⛏ / 💀
	// Death edge, on EVERY screen (hp replicates): the corpse persists, so
	// it carries its own pyre — an entity hanging FX on itself needs no
	// game plumbing at all.
	if self.hp <= 0 && !self.was_dead {
		self.was_dead = true
		if cast(rawptr)self.pyre != nil {
			gd.node_queue_free(cast(gd.Node)self.pyre)
		}
		self.pyre = fx_burst_node(cast(gd.Node)self.owner, 0, 0, {1, 0.3, 0.2, 1})
	} else if self.hp > 0 {
		self.was_dead = false
	}
}
