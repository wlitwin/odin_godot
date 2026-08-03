//gd:extends Area2D
//gd:class XpGem
//gd:group gems
package survivors_scripts

// ----------------------------------------------------------------------------
// XpGem — the pickup an enemy drops on death. It sits still until the player comes within
// pickup_range, then it MAGNETS toward the player; on overlap it grants its XP and frees.
//
// FEATURES:
//   * @export value                  — XP granted (the enemy sets it TYPED at spawn).
//   * lifecycle _physics_process      — read the player's live pickup_range (typed) and drift.
//   * @(gd_connect) body_entered      — collect on the player's body overlap.
//   * typed cross-script WRITE        — calls player_gain_xp, which banks XP + may level us up.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

XpGem :: struct {
	owner:     gd.Area2d,
	value:     int `gd:"export"`, // XP this gem is worth (set by the enemy that dropped it)
	collected: bool,
}

xp_gem_ready :: proc(self: ^XpGem) {
	// Zero-guard, deliberately not `gd:"default=1"`: xp_gem.tscn STORES `value`, so a declared
	// default would be overwritten by the scene load — the guard is what actually protects a
	// zero-seeded gem. ("gems" group membership is declared with //gd:group at the top.)
	if self.value == 0 {self.value = 1}
}

xp_gem_physics_process :: proc(self: ^XpGem, delta: f64) {
	if self.collected {return}
	player := find_player(self.owner)
	if player == nil {return}
	p := rt.script_of(player, Player)
	if p == nil {return}

	me := gd.node2d_get_global_position(self.owner)
	pp := gd.node2d_get_global_position(player)
	d := gd.Vector2{pp.x - me.x, pp.y - me.y}
	dist := d.x * d.x + d.y * d.y
	rng := p.pickup_range
	if dist <= rng * rng {
		// Within magnet range — accelerate toward the player.
		dir := gd.normalized(d)
		pull := f32(140) + rng // closer => snappier (range adds a base speed)
		me.x += dir.x * pull * f32(delta)
		me.y += dir.y * pull * f32(delta)
		gd.node2d_set_global_position(self.owner, me)
	}
}

// on_body — collect when the player's body overlaps. Grants XP TYPED (which may level the
// player up), then frees the gem.
@(gd_method, gd_connect = "body_entered")
xp_gem_on_body :: proc(self: ^XpGem, body: gd.Node2d) {
	if self.collected {return}
	p := rt.script_of(body, Player)
	if p == nil {return}
	self.collected = true
	player_gain_xp(p, self.value)
	gd.node_queue_free(self.owner)
}
