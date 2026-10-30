package scrapyard_defs

import "core:fmt"
import gd "godot:godot"
import rgd "godot:replay/godot"
import content "../../shared/content"

// One explicit mapping for game admission, export, archetypes and previews.
// The mapping supplies game bounds; Resource/Inspector metadata never guesses it.
bake_mob :: proc(resource: gd.Resource, ctx: ^rgd.Bake_Context, path: string) -> (u8, content.Mob) {
	source := rgd.bake_resource(ctx, resource, MobDef, path)
	if source == nil {
		return 0, {}
	}
	id := rgd.bake_integer(ctx, u8, source.id, 0, content.MAX_MOBS - 1, fmt.tprintf("%s.id", path))
	result := content.Mob {
		name = content.name(gd.gd_string_to_odin(source.name)),
		hp = rgd.bake_integer(ctx, u16, source.hp, 1, 65535, fmt.tprintf("%s.hp", path)),
		bite = rgd.bake_integer(ctx, u8, source.bite, 0, 255, fmt.tprintf("%s.bite", path)),
		speed = source.speed,
		radius = source.body_r,
		scale = source.scale,
		prop = source.prop,
		boom_damage = rgd.bake_integer(ctx, u8, source.boom_dmg, 0, 255, fmt.tprintf("%s.boom_dmg", path)),
		boom_radius = source.boom_radius,
		boom_status = status_reference(ctx, cast(gd.Resource)source.boom_status, fmt.tprintf("%s.boom_status", path)),
	}
	if source.pulse != nil {
		pulse := rgd.bake_resource(ctx, cast(gd.Resource)source.pulse, PulseDef, fmt.tprintf("%s.pulse", path))
		if pulse == nil {
			return 0, {}
		}
		result.pulse = {
			windup = rgd.bake_integer(
				ctx,
				u16,
				pulse.windup_ticks,
				1,
				180,
				fmt.tprintf("%s.pulse.windup_ticks", path),
			),
			cooldown = rgd.bake_integer(
				ctx,
				u16,
				pulse.cooldown_ticks,
				30,
				3600,
				fmt.tprintf("%s.pulse.cooldown_ticks", path),
			),
			radius = pulse.radius,
			damage = rgd.bake_integer(ctx, u8, pulse.damage, 1, 20, fmt.tprintf("%s.pulse.damage", path)),
		}
		if !content.pulse_valid(result.pulse) {
			rgd.bake_fail(
				ctx,
				fmt.tprintf("%s.pulse", path),
				"invalid pulse ranges; radius must be finite and 32..400",
			)
		}
	}
	if !content.mob_valid(result) {
		rgd.bake_fail(ctx, path, "invalid mob values")
	}
	return id, result
}
