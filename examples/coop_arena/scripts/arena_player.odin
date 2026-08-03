//gd:extends Node2D
//gd:class ArenaPlayer
//gd:group arena_pawns
package coop_arena

// ----------------------------------------------------------------------------
// ArenaPlayer — an OWNER-AUTHORITATIVE player pawn (root of arena_player.tscn). Each peer OWNS
// its own pawn: the node's multiplayer authority is set to the owning peer, so the sibling
// MultiplayerSynchronizer (authority follows the node, set recursively at spawn) streams the
// OWNER's `position` (native) + `hp` (an Odin @export) to every other peer.
//
// The whole point — RESPONSIVENESS: the owner simulates its OWN pawn LOCALLY, every frame, with
// ZERO round-trip:
//   * movement — read the input axes + ease velocity (momentum) and move, right here, the same
//     frame the key is down. No "send input to host, wait for the authoritative position back".
//   * auto-fire — find the nearest enemy and, when one is in range, fire IMMEDIATELY: the bullet
//     is spawned LOCALLY this frame (the owner sees its own shot with no network delay) and the
//     shot is then BROADCAST so other peers spawn a matching ghost. (See arena.odin / arena_bullet.odin.)
//
// Non-owners run NONE of this — their physics tick early-returns; they just render the synced
// transform. So both pawns are visible + smoothly synced on both screens, but each player's own
// pawn answers its own input with no host in the loop.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "core:math"

MOVE_ACCEL_RATE :: f32(8.0)

ArenaPlayer :: struct {
	owner:   gd.Node2d,
	hp:      int `gd:"export"`, // synced (owner-authoritative) so peers see each other's health
	peer_id: int,               // who owns this pawn (set on spawn from the node name)
	armed:   bool,              // auto-fire enabled (the orchestrator disarms the host's own pawn
	                            // in the headless co-op test so the CLIENT is the deterministic shooter)

	// tuning — Inspector-tunable exports; `default=` applies the value before _ready (and the
	// Inspector's reset arrow knows it), replacing the old if-zero guard block in _ready.
	move_speed: f32 `gd:"export,default=180"`,
	fire_cd:    f32 `gd:"export,default=0.3"`,
	range:      f32 `gd:"export,default=240"`,
	damage:     int `gd:"export,default=6"`,

	// runtime
	vel:        gd.Vector2,
	fire_timer: f32,
	color:      gd.Color,
}

@(private = "file")
approach :: proc(cur, target, max_delta: f32) -> f32 {
	if cur < target {r := cur + max_delta; return target if r > target else r}
	if cur > target {r := cur - max_delta; return target if r < target else r}
	return cur
}

arena_player_ready :: proc(self: ^ArenaPlayer) {
	// hp KEEPS its ready-time guard rather than `default=`: arena_player.tscn stores hp=100
	// explicitly (the synchronizer spawn-replicates it), so the guard stays as the belt.
	if self.hp == 0 {self.hp = 100}
	self.color = gd.Color{0.35, 0.65, 1, 1}
	// group membership is declared by the `//gd:group arena_pawns` marker up top (joined at
	// READY, before this proc runs) — no gd.add_to_group boilerplate here.
}

// arena_player_recolor tints the Body Polygon2D + remembers the colour (bullets inherit it).
// gd.peer_color is the framework's per-peer tint (host id 1 blue, warm hues after).
arena_player_recolor :: proc(self: ^ArenaPlayer, peer_id: int) {
	self.peer_id = peer_id
	self.color = gd.peer_color(peer_id)
	body := gd.get_node(self.owner, "Body")
	if body != nil {gd.polygon2d_set_color(cast(gd.Polygon2d)body, self.color)}
}

arena_player_process :: proc(self: ^ArenaPlayer, delta: f64) {
	// OWNER-AUTHORITATIVE GATE: only the peer that owns this pawn simulates it. Everyone else
	// just renders the position the synchronizer streamed in. This is what makes your own pawn
	// answer your input with no round-trip while still appearing on the other screen.
	if !bool(gd.node_is_multiplayer_authority(self.owner)) {return}

	// --- LOCAL movement (momentum). In free play this reads your keys; in the headless test
	// there is no input (axes are 0) and the orchestrator nudges the pawn instead — either way
	// the OWNER writes its own position locally and the synchronizer replicates it. ---
	// gd.sname interns a literal as a STATIC StringName — safe (and idiomatic) per call.
	input := gd.singleton_input()
	dx := f32(gd.input_get_axis(input, gd.sname("ui_left"), gd.sname("ui_right")))
	dy := f32(gd.input_get_axis(input, gd.sname("ui_up"), gd.sname("ui_down")))
	if dx != 0 || dy != 0 {
		tvx := dx * self.move_speed
		tvy := dy * self.move_speed
		if dx != 0 && dy != 0 {inv := f32(0.70710677); tvx *= inv; tvy *= inv}
		step := self.move_speed * MOVE_ACCEL_RATE * f32(delta)
		self.vel.x = approach(self.vel.x, tvx, step)
		self.vel.y = approach(self.vel.y, tvy, step)
		pos := gd.node2d_get_position(self.owner)
		pos.x = clamp(pos.x + self.vel.x * f32(delta), 8, ARENA_W - 8)
		pos.y = clamp(pos.y + self.vel.y * f32(delta), 8, ARENA_H - 8)
		gd.node2d_set_position(self.owner, pos)
	}

	// --- LOCAL auto-fire: the owner resolves its own shots immediately. ---
	// fire_timer stays a hand-rolled COOLDOWN (not play.every): it only resets on an actual
	// shot, so a pawn that held fire shoots the INSTANT an enemy enters range — a cadence
	// timer would delay that shot (or burst after a dry spell).
	if !self.armed {return}
	self.fire_timer -= f32(delta)
	if self.fire_timer > 0 {return}
	origin := gd.node2d_get_global_position(self.owner)
	target, ok := gd.nearest_in_group(self.owner, GROUP_ENEMIES, origin)
	if !ok {return}
	tpos := gd.node2d_get_global_position(target)
	d := gd.Vector2{tpos.x - origin.x, tpos.y - origin.y}
	dist := math.sqrt(d.x * d.x + d.y * d.y)
	if dist > self.range {return} // nothing in range — hold fire
	self.fire_timer = self.fire_cd
	game := find_game(self.owner)
	if game == nil {return}
	arena_player_fire(game, self.peer_id, origin, gd.normalized(d), self.damage, self.color)
}
