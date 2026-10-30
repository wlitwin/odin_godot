package scrapyard_defs

import "core:fmt"
import gd "godot:godot"
import content "../../shared/content"
import scenegd "godot:replay/godot/scene"

bake_ability :: proc(resource: gd.Resource, ctx: ^scenegd.Bake_Context, path: string) -> (u8, content.Ability) {
	source := scenegd.bake_resource(ctx, resource, AbilityDef, path)
	if source == nil {
		return 0, {}
	}
	id := scenegd.bake_integer(ctx, u8, source.id, 1, content.MAX_ABILITIES - 1, fmt.tprintf("%s.id", path))
	family := scenegd.bake_integer(ctx, u8, source.family, 0, 5, fmt.tprintf("%s.family", path))
	result := content.Ability {
		name = content.name(gd.gd_string_to_odin(source.name)),
		family = content.Ability_Family(family),
		cooldown = scenegd.bake_integer(ctx, u16, source.cooldown, 1, 3600, fmt.tprintf("%s.cooldown", path)),
		range = source.range,
		radius = source.radius,
		arc_cos = source.arc_cos,
		speed = source.speed,
		damage = scenegd.bake_integer(ctx, u8, source.dmg, 0, 255, fmt.tprintf("%s.dmg", path)),
		status = status_reference(ctx, cast(gd.Resource)source.status, fmt.tprintf("%s.status", path)),
		self_buff = source.self_buff,
		duration = scenegd.bake_integer(ctx, u16, source.duration, 0, 36000, fmt.tprintf("%s.duration", path)),
		pulse = scenegd.bake_integer(ctx, u16, source.pulse, 1, 600, fmt.tprintf("%s.pulse", path)),
	}
	if source.turret != nil {
		turret := scenegd.bake_resource(ctx, cast(gd.Resource)source.turret, TurretDef, fmt.tprintf("%s.turret", path))
		if turret == nil {
			return 0, {}
		}
		result.turret = {
			ammo = scenegd.bake_integer(ctx, u16, turret.ammo, 1, 1000, fmt.tprintf("%s.turret.ammo", path)),
			cadence = scenegd.bake_integer(ctx, u16, turret.cadence, 1, 120, fmt.tprintf("%s.turret.cadence", path)),
			damage = scenegd.bake_integer(ctx, u8, turret.damage, 1, 100, fmt.tprintf("%s.turret.damage", path)),
			speed = turret.speed,
			ttl = scenegd.bake_integer(ctx, u16, turret.ttl, 1, 600, fmt.tprintf("%s.turret.ttl", path)),
			use_radius = turret.use_radius,
		}
		if !content.turret_valid(result.turret) {
			scenegd.bake_fail(ctx, fmt.tprintf("%s.turret", path), "invalid turret projectile or interaction radius")
		}
	}
	names := [4]string{"range", "radius", "arc_cos", "speed"}
	for value, i in ([4]f32{source.range, source.radius, source.arc_cos, source.speed}) {
		field := names[i]
		lower := i == 2 ? f32(-1) : i == 3 ? f32(1) : f32(0)
		upper := i == 2 ? f32(1) : i == 3 ? f32(100) : f32(1000)
		if !content.finite(value) || value < lower || value > upper {
			scenegd.bake_fail(ctx, fmt.tprintf("%s.%s", path, field), "value is nonfinite or outside gameplay bounds")
		}
	}
	if result.family == .Zone && result.duration == 0 {
		scenegd.bake_fail(ctx, fmt.tprintf("%s.duration", path), "Zone abilities require a positive duration")
	}
	if !content.ability_valid(result, content.MAX_STATUS) {
		scenegd.bake_fail(ctx, path, "invalid ability values")
	}
	return id, result
}
