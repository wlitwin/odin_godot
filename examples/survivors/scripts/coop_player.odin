//gd:extends Node2D
//gd:class CoopPlayer
package survivors_scripts

// ----------------------------------------------------------------------------
// CoopPlayer — the root of coop_player.tscn (a replicated player avatar). Each peer OWNS its
// own player (the node's multiplayer authority = that peer); a sibling MultiplayerSynchronizer
// (configured in coop_player.tscn) streams the authority's `position` (native) + this script's
// @export `hp` (the Odin-property-through-the-synchronizer path proven by the spike) to every
// other peer. Movement/aim is driven by the net orchestrator on the OWNING peer; everyone else
// just renders the synchronized transform — so both players are visible + synced on both peers.
// ----------------------------------------------------------------------------

import gd "godot:godot"

CoopPlayer :: struct {
	owner:   gd.Node2d,
	hp:      int `gd:"export"`, // alive/health — synced (an Odin field through the synchronizer)
	peer_id: int,               // who owns this avatar (not synced; set on spawn from the name)
}

coop_player_ready :: proc(self: ^CoopPlayer) {
	if self.hp == 0 {self.hp = 100}
}

// recolor tints the Body Polygon2D (host = blue, others = orange) so the two avatars are
// visually distinct on both screens.
coop_player_recolor :: proc(self: ^CoopPlayer, is_host: bool) {
	body := gd.get_node(self.owner, "Body")
	if body == nil {return}
	c := gd.Color{0.35, 0.65, 1, 1}
	if !is_host {c = gd.Color{1, 0.62, 0.2, 1}}
	gd.polygon2d_set_color(cast(gd.Polygon2d)body, c)
}
