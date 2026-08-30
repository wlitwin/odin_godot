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
import ksess "godot:kit/session"

Spelunker :: struct {
	owner:     gd.Node2d,
	glyph:     gd.Label `gd:"onready=Glyph"`,
	pyre:      gd.Cpu_Particles2d `gd:"onready=Pyre"`, // authored death burst
	net_id:    knet.Net_Id, // assigned by the session at spawn
	x, y:      f32 `gd:"owner,wire=f16"`, // half floats on the wire — cave
	// coordinates fit f16 to sub-pixel; the struct (and everything local: shadows,
	// prediction, ring blobs) stays full f32
	bag:       [6]kitems.Slot `gd:"replicate"`,
	hp:        i32 `gd:"replicate,wire=spelunker_hp_codec"`, // 0..MAX_HP ships as ONE byte
	stamina:   i32 `gd:"replicate"`,
	cds:       [2]u16 `gd:"replicate"`, // ability cooldowns, host-decayed
	fx:        [2]kcombat.Effect `gd:"replicate"`, // status effects, host-decayed
	php:       kcombat.Predicted_Hp, // scratch: impacts SEEN here, pre-truth
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
// host's consequence below mints the Pickup entity everyone sees.
@(gd_command = knet.ACTION_OWNER_PREDICTED)
spelunker_drop :: proc(self: ^Spelunker, slot: i32) -> (ok: bool, dropped: kitems.Slot) {
	if self.hp <= 0 {return false, {}} // the dead drop everything on their own
	dropped = kitems.take(self.bag[:], int(slot), max(u16))
	return dropped.count > 0, dropped
}

// Host only: what left the bag becomes a Pickup on the floor.
@(gd_half)
spelunker_drop_then :: proc(game: ^CaveLobby, self: ^Spelunker, by: knet.Player_Id, slot: i32, dropped: kitems.Slot) {
	cave_mint_pickup(game, self, dropped)
}

// Throw a rock: the WHOLE cast, zero role branches. The gate (alive +
// cooldown + stamina) bites instantly on the thrower's screen and refuses
// identically on the host; the consequence below launches the authoritative
// rock from the leashed origin the verb returns as payload.
//
// The cast carries its ORIGIN (ox, oy): a moving shooter's own screen is
// the truth for where the rock left from — its position is owner-streamed,
// so the host's copy lags a stream behind, and launching from the lagged
// copy makes the authoritative rock fly a different line than the one the
// shooter SAW hit. Leashed against our copy: honest latency offsets pass,
// teleports don't (on the caster's own prediction ox,oy == x,y — no-op).
@(gd_command = knet.ACTION_OWNER_PREDICTED)
spelunker_throw :: proc(self: ^Spelunker, dx: f32, dy: f32, ox: f32, oy: f32) -> (ok: bool, fx: f32, fy: f32) {
	if self.hp <= 0 {return false, 0, 0}
	if dx == 0 && dy == 0 {return false, 0, 0}
	if !kcombat.ability_try(self.cds[:], 0, ROCK_ABILITY, &self.stamina) {return false, 0, 0}
	from := kcombat.leash({ox, oy, 0}, {self.x, self.y, 0}, CAST_LEASH)
	return true, from.x, from.y
}

// Host only: the confirmed cast launches the one rock that hurts.
@(gd_half)
spelunker_throw_then :: proc(game: ^CaveLobby, self: ^Spelunker, by: knet.Player_Id, dx: f32, dy: f32, ox: f32, oy: f32, fx: f32, fy: f32) {
	cave_launch_rock(game, by, {fx, fy}, {dx, dy})
}

// REVIVE a downed friend — the co-op staple, as one ordinary command on
// the DOWNED player's entity (it mutates only its target, so no hook is
// needed). The reviver stands in reach; back up at REVIVE_HP, in place —
// the was_dead edge in process tells a revive (hp < full) from a bleed-out
// respawn (full hp at the spawn point) and skips the grave-walk teleport.
// Add a channel timer on top if your game wants held-E revives.
// PREDICTED: the friend is up on the reviver's screen this frame; a stale
// revive (they bled out between screens) reverts through reject-truth.
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
spelunker_revive :: proc(self: ^Spelunker, px: f32, py: f32) -> bool {
	if self.hp > 0 {return false} // not down: nothing to revive
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	self.hp = REVIVE_HP
	return true
}

// Bandage up: the second ability slot. Self-targeted, so this command IS
// the whole effect — no host hook half at all: the same proc heals
// instantly on the caster's screen and re-runs authoritatively on the host.
@(gd_command = knet.ACTION_OWNER_PREDICTED)
spelunker_heal :: proc(self: ^Spelunker) -> bool {
	if self.hp <= 0 || self.hp >= MAX_HP {return false} // corpses and the hale need no bandage
	if !kcombat.ability_try(self.cds[:], 1, HEAL_ABILITY, &self.stamina) {return false}
	self.hp = min(self.hp + HEAL_AMOUNT, MAX_HP)
	return true
}

spelunker_process :: proc(self: ^Spelunker, delta: f64) {
	gd.node2d_set_position(self.owner, {self.x, self.y})
	// Everyone can see who's dead — the corpse glyph replicates with hp.
	gd.set_text(cast(gd.Object)self.glyph, self.hp > 0 ? "\xE2\x9B\x8F" : "\xF0\x9F\x92\x80") // ⛏ / 💀
}

// THE HP EDGE — death and return, one half for every screen, no was_dead
// mirrors. The DOWNWARD crossing fires the pyre everywhere (the corpse
// persists and carries its own particles) and stops the owner's feet; the
// UPWARD crossing is owner business — position is owner-streamed, only I can
// move me — and the value tells a bled-out respawn (full hp: a fresh body at
// the spawn point) from a revive where I fell. A late joiner seeing an OLD
// corpse gets the glyph, not a fresh pyre burst: spawn values seed silently —
// the exact "old wounds present as fresh hits" bug the mirrors used to have.
// (The host's own restores edge SAME-frame because cavecrawl.odin calls
// session_run_edges right after its host-tick loop — the walk-out must move
// the body before the next exchange, the acid's crossfire lesson.)
@(gd_half)
spelunker_hp_edge :: proc(g: ^CaveLobby, self: ^Spelunker, old, new: i32) {
	if new <= 0 && old > 0 {
		gd.cpu_particles2d_restart(self.pyre, false)
		if self == g.me_spel {
			g.walking = false
			gd.print_str("CAVE_DIED")
		}
	}
	if new > 0 && old <= 0 && self == g.me_spel {
		if new >= MAX_HP {
			// BLED OUT and back: a fresh body at the spawn point.
			self.x = SPAWN_X
			self.y = SPAWN_Y
			_ = spelunker_teleport(&g.boot, self) // out of the grave in one step, on every screen
			gd.print_str("CAVE_RESPAWNED")
		} else {
			// REVIVED where I fell — a friend got there before the clock.
			gd.print_str("CAVE_REVIVED")
		}
	}
}
