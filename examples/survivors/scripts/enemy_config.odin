//gd:extends Resource
//gd:class EnemyConfig
package survivors_scripts

// ----------------------------------------------------------------------------
// EnemyConfig — a CUSTOM RESOURCE (data asset) authored in Odin.
//
// FEATURE: custom Resource (`//gd:extends Resource`). A Resource is a RefCounted data
// container, NOT a scene-tree node — so it has no _ready/_process; it is pure data. Its
// `@export` fields are STORAGE properties, so Godot's text serializer reads/writes them in
// a `.tres` along with a reference to this script. We ship two instances with different
// stats + colors: `grunt.tres` (weak, fast, cyan) and `brute.tres` (tanky, slow, red).
//
// FEATURE: `@export` of varied types + a range hint + a Color. `speed` carries a
// `range=20:200:5` hint, so the Inspector shows a slider; `color` is a full Color picker.
//
// FEATURE: global class_name. Because of `//gd:class EnemyConfig`, "EnemyConfig" is
// registered as a first-class engine type — which is what lets enemy.odin's
// `@export config: ^gd.Resource `gd:"export,resource=EnemyConfig"`` filter its picker to
// exactly these assets.
// ----------------------------------------------------------------------------

import gd "godot:godot"

EnemyConfig :: struct {
	// A Resource's owner handle is `gd.Resource` (a RefCounted), not a node handle.
	owner:  gd.Resource,
	hp:     gd.Int   `gd:"export"`, // hit points before the enemy dies
	speed:  f32      `gd:"export,range=20:200:5"`, // chase speed (px/s) — Inspector slider
	color:  gd.Color `gd:"export"`, // body tint, applied to the enemy's Polygon2D
	points: gd.Int   `gd:"export"`, // score awarded to the player when this enemy dies
}
