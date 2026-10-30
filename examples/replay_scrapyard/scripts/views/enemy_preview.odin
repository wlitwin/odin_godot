//gd:extends Resource
//gd:class ScrapEnemyPreview
package scrap_views

import gd "godot:godot"
import d "godot:replay/definitions"
import defs "../defs"
import display "../../shared/presentation"
import scenegd "godot:replay/godot/scene"

// Authored samples for the same detached view interface used during live play.
// No Session/World and no kind-specific preview switch.
ScrapEnemyPreview :: struct {
	owner: gd.Resource,
	definition: ^gd.Resource `gd:"export,resource=MobDef"`,
	attacking: bool `gd:"export"`,
	warning: bool `gd:"export"`,
	fraction: f32 `gd:"export,range=0:1:0.01"`,
	warning_radius: f32 `gd:"export,range=1:400:1"`,
}

enemy_preview_value :: proc(resource: gd.Resource) -> (display.Mob_View, d.Report) {
	ctx: scenegd.Bake_Context
	source := scenegd.bake_resource(&ctx, resource, ScrapEnemyPreview, "$preview")
	if source == nil {
		return {}, ctx.report
	}
	id, definition := defs.bake_mob(cast(gd.Resource)source.definition, &ctx, "$preview.definition")
	if ctx.report.error != .None {
		return {}, ctx.report
	}
	if !(source.fraction >= 0 && source.fraction <= 1) ||
	   !(source.warning_radius >= 1 && source.warning_radius <= 400) {
		return {}, d.problem(.Invalid, "$preview", "invalid fraction or warning radius")
	}
	charged := definition.pulse.windup > 0
	return {
		kind = id,
		hp = definition.hp,
		scale = definition.scale,
		tint = {1, 1, 1, 1},
		near = source.attacking,
		prop = definition.prop,
		telegraph = source.warning,
		charged_attack = charged,
		telegraph_radius = charged ? definition.pulse.radius : source.warning_radius,
		growth = source.fraction,
	}, {}
}
