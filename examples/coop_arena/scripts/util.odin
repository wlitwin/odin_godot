package coop_arena

// ----------------------------------------------------------------------------
// util — shared, owner-less helpers for the co-op arena (no //gd:class, so scriptgen skips
// this file; it is plain package Odin compiled into the one scripts dll, shared by every
// arena script). Groups give a decoupled "find that kind of thing" query with no node paths:
// each script declares its membership with a `//gd:group` marker, and these constants name
// the same groups for the query side (gd.first_in_group / gd.nearest_in_group /
// rt.scripts_in_group). Generic spatial queries live in the framework now; only the
// GAME-SPECIFIC lookups (typed orchestrator handle, id-keyed enemy resolve) remain here.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

ARENA_W :: f32(640)
ARENA_H :: f32(360)

GROUP_GAME :: "arena_game"       // joined by arena.odin's //gd:group marker
GROUP_ENEMIES :: "arena_enemies" // joined by arena_enemy.odin's //gd:group marker
GROUP_PAWNS :: "arena_pawns"     // joined by arena_player.odin's //gd:group marker

// find_game returns the ArenaGame SCRIPT on the root node, or nil — the typed handle the
// pawn/bullet use to reach the orchestrator (to broadcast fire/damage RPCs on a node whose
// path is identical on every peer).
find_game :: proc "contextless" (from: gd.Object) -> ^ArenaGame {
	return rt.first_script_in_group(from, GROUP_GAME, ArenaGame)
}

// enemy_by_id finds the ArenaEnemy whose synced `id` matches, scanning GROUP_ENEMIES. Returns
// the node + its script, or (nil, nil). Used by the peer-authoritative damage RPC so every
// peer resolves the SAME enemy regardless of how the spawner named the node.
enemy_by_id :: proc(from: gd.Object, id: int) -> (gd.Node, ^ArenaEnemy) {
	for e in rt.scripts_in_group(from, GROUP_ENEMIES, ArenaEnemy) {
		if e.id == id {return e.owner, e}
	}
	return nil, nil
}
