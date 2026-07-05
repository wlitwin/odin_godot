//gd:extends Node2D
//gd:class Spelunker
package cavecrawl_scripts

// A player's avatar — THE toolkit author surface for a multiplayer entity:
// tag the fields, done. x/y are owner-streamed (whoever owns this spelunker
// writes them; everyone else sees interpolated motion), the bag replicates
// to everyone (co-op transparency: you can see what your friends carry),
// plus the combat block: hp, stamina, ability cooldowns, status effects —
// all plain replicated POD the host decays and deltas carry.
//
// The BODY is an authored scene (entities/spelunker.tscn): a Node2D this
// script drives, a Glyph label, and a pre-configured Pyre emitter for the
// death burst — visuals live in the editor, the struct only tags what
// replicates. `onready` wires the children by path.

import gd "godot:godot"
import kcombat "godot:kit/combat"
import kitems "godot:kit/items"
import kinter "godot:kit/interact"
import knet "godot:kit/net"

Spelunker :: struct {
	owner:     gd.Node2d,
	glyph:     gd.Label `gd:"onready=Glyph"`,
	pyre:      gd.Cpu_Particles2d `gd:"onready=Pyre"`, // authored death burst
	net_id:    knet.Net_Id, // assigned by the session at spawn
	x, y:      f32 `gd:"replicate,interp,owner,wire=f16"`, // half floats on the wire — cave
	// coordinates fit f16 to sub-pixel; the struct (and everything local: shadows,
	// prediction, ring blobs) stays full f32
	bag:       [6]kitems.Slot `gd:"replicate"`,
	hp:        i32 `gd:"replicate,wire=spelunker_hp_codec"`, // 0..MAX_HP ships as ONE byte
	stamina:   i32 `gd:"replicate"`,
	cds:       [2]u16 `gd:"replicate"`, // ability cooldowns, host-decayed
	fx:        [2]kcombat.Effect `gd:"replicate"`, // status effects, host-decayed
	last_drop: kitems.Slot, // scratch for the drop hook — never on the wire
	aim:       [2]f32, // scratch for the throw hook — never on the wire
	cast_from: [2]f32, // scratch: where the throw REALLY left from (owner truth, leashed)
	php:       kcombat.Predicted_Hp, // scratch: impacts SEEN here, pre-truth
	was_dead:  bool, // scratch: death-edge detector for the pyre burst
}

// The hp wire codec: an i32 whose whole gameplay range is 0..MAX_HP has no
// business spending four wire bytes. encode/decode are exact over that range,
// so nothing downstream (death edges, the hp==REVIVE_HP contract) can drift —
// pick codecs whose round trip is exact for every value the game produces.
spelunker_hp_codec :: knet.Wire_Codec {
	size   = 1,
	encode = proc(wire, field: rawptr) {(^u8)(wire)^ = u8(clamp((^i32)(field)^, 0, 255))},
	decode = proc(field, wire: rawptr) {(^i32)(field)^ = i32((^u8)(wire)^)},
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
//
// The cast carries its ORIGIN (ox, oy): a moving shooter's own screen is
// the truth for where the rock left from — its position is owner-streamed,
// so the host's copy lags a stream behind, and launching from the lagged
// copy makes the authoritative rock fly a different line than the one the
// shooter SAW hit. Leashed against our copy: honest latency offsets pass,
// teleports don't (on the caster's own prediction ox,oy == x,y — no-op).
@(gd_command = "predict")
spelunker_throw :: proc(self: ^Spelunker, dx: f32, dy: f32, ox: f32, oy: f32) -> bool {
	if self.hp <= 0 {return false}
	if dx == 0 && dy == 0 {return false}
	if !kcombat.ability_try(self.cds[:], 0, ROCK_ABILITY, &self.stamina) {return false}
	from := kcombat.leash({ox, oy, 0}, {self.x, self.y, 0}, CAST_LEASH)
	self.cast_from = {from.x, from.y}
	self.aim = {dx, dy}
	return true
}

// REVIVE a downed friend — the co-op staple, as one ordinary command on
// the DOWNED player's entity (it mutates only its target, so no hook is
// needed). The reviver stands in reach; back up at REVIVE_HP, in place —
// the was_dead edge in process tells a revive (hp < full) from a bleed-out
// respawn (full hp at the spawn point) and skips the grave-walk teleport.
// Add a channel timer on top if your game wants held-E revives.
// PREDICTED: the friend is up on the reviver's screen this frame; a stale
// revive (they bled out between screens) reverts through reject-truth.
@(gd_command = "predict")
spelunker_revive :: proc(self: ^Spelunker, px: f32, py: f32) -> bool {
	if self.hp > 0 {return false} // not down: nothing to revive
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	self.hp = REVIVE_HP
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

spelunker_process :: proc(self: ^Spelunker, delta: f64) {
	gd.node2d_set_position(self.owner, {self.x, self.y})
	// Everyone can see who's dead — the corpse glyph replicates with hp.
	gd.set_string(cast(gd.Object)self.glyph, "text", self.hp > 0 ? "\xE2\x9B\x8F" : "\xF0\x9F\x92\x80") // ⛏ / 💀
	// Death edge, on EVERY screen (hp replicates): the corpse persists, so
	// it carries its own pyre — authored in spelunker.tscn, fired here.
	if self.hp <= 0 && !self.was_dead {
		self.was_dead = true
		gd.cpu_particles2d_restart(self.pyre, false)
	} else if self.hp > 0 {
		self.was_dead = false
	}
}
