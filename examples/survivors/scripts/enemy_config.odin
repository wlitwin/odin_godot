//gd:extends Resource
//gd:class EnemyConfig
package survivors_scripts

// ----------------------------------------------------------------------------
// EnemyConfig — a CUSTOM RESOURCE (data asset) authored in Odin. It is the data half of an
// enemy: enemy.tscn is the body + collision, this resource is all the stats. We ship four
// instances (swarmer / grunt / brute / tank), so the SAME enemy.tscn becomes four very
// different monsters just by swapping the `.tres` the spawner assigns.
//
// FEATURES exercised here:
//   * custom Resource (`//gd:extends Resource`)        — a RefCounted data container, no
//                                                        lifecycle, pure `@export` data.
//   * `@export` of every scalar shape                  — int, f32 (with `range=` sliders),
//                                                        and a full `gd.Color` picker.
//   * global class_name (`//gd:class EnemyConfig`)     — lets enemy.odin's `config` field
//                                                        type-FILTER its resource picker to
//                                                        exactly these assets.
//   * `.tres` round-trip                               — Godot's text serializer reads/writes
//                                                        these fields automatically.
// ----------------------------------------------------------------------------

import gd "godot:godot"

EnemyConfig :: struct {
	// A Resource's owner handle is `gd.Resource` (a RefCounted), not a node handle.
	owner:     gd.Resource,
	hp:        gd.Int   `gd:"export,range=1:400:1"`, // hit points before it dies
	speed:     f32      `gd:"export,range=10:200:5"`, // chase speed (px/s) — Inspector slider
	damage:    gd.Int   `gd:"export,range=1:100:1"`, // contact damage dealt to the player
	xp_value:  gd.Int   `gd:"export,range=1:100:1"`, // XP dropped (as a gem) on death
	points:    gd.Int   `gd:"export,range=1:100:1"`, // score awarded on death
	radius:    f32      `gd:"export,range=4:40:1"`, // body size (px) — scales the polygon + shape
	color:     gd.Color `gd:"export"`, // body tint, applied to the enemy's Polygon2D
}
