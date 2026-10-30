//gd:extends Resource
//gd:class ScrapEnemyArchetype
package scrap_views

import gd "godot:godot"

// Stable gameplay identity comes from MobDef.id. Scene and appearance stay local.
ScrapEnemyArchetype :: struct {
	owner: gd.Resource,
	definition: ^gd.Resource `gd:"export,resource=MobDef"`,
	scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
	appearance: ^gd.Resource `gd:"export,resource=ScrapEnemyStyle"`,
}
