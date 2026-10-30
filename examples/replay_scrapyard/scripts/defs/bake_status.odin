package scrapyard_defs

import "core:fmt"
import gd "godot:godot"
import content "../../shared/content"
import scenegd "godot:replay/godot/scene"

bake_status :: proc(resource: gd.Resource, ctx: ^scenegd.Bake_Context, path: string) -> (u8, content.Status) {
	source := scenegd.bake_resource(ctx, resource, StatusDef, path)
	if source == nil {
		return 0, {}
	}
	id := scenegd.bake_integer(ctx, u8, source.id, 1, content.MAX_STATUS - 1, fmt.tprintf("%s.id", path))
	result := content.Status {
		name = content.name(gd.gd_string_to_odin(source.name)),
		duration = scenegd.bake_integer(ctx, u16, source.duration, 1, 36000, fmt.tprintf("%s.duration", path)),
		max_stacks = scenegd.bake_integer(ctx, u8, source.max_stacks, 1, 9, fmt.tprintf("%s.max_stacks", path)),
		move_mult = source.move_mult,
		dot_damage = scenegd.bake_integer(ctx, i8, source.dot_dmg, -20, 20, fmt.tprintf("%s.dot_dmg", path)),
		dot_every = scenegd.bake_integer(ctx, u16, source.dot_every, 0, 600, fmt.tprintf("%s.dot_every", path)),
		taken_mult = source.taken_mult,
		dealt_mult = source.dealt_mult,
		tint = {source.tint.r, source.tint.g, source.tint.b, source.tint.a},
	}
	if !content.status_valid(result) {
		scenegd.bake_fail(ctx, path, "invalid status multipliers, tint or name")
	}
	return id, result
}

bake_combo :: proc(resource: gd.Resource, ctx: ^scenegd.Bake_Context, path: string) -> content.Combo {
	source := scenegd.bake_resource(ctx, resource, ComboDef, path)
	if source == nil {
		return {}
	}
	result := content.Combo {
		present = status_reference(ctx, cast(gd.Resource)source.present, fmt.tprintf("%s.present", path), true),
		incoming = status_reference(ctx, cast(gd.Resource)source.incoming, fmt.tprintf("%s.incoming", path), true),
		output = status_reference(ctx, cast(gd.Resource)source.output, fmt.tprintf("%s.output", path)),
		reaction = content.Reaction(
			scenegd.bake_integer(ctx, u8, source.reaction, 0, 2, fmt.tprintf("%s.reaction", path)),
		),
		damage = scenegd.bake_integer(ctx, u8, source.dmg, 0, 255, fmt.tprintf("%s.dmg", path)),
		radius = source.radius,
		consume = source.consume,
	}
	if !content.finite(result.radius) || result.radius < 0 || result.radius > 1000 {
		scenegd.bake_fail(ctx, fmt.tprintf("%s.radius", path), "invalid reaction radius")
	}
	return result
}
