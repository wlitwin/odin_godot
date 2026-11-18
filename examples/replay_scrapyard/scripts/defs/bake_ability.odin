package scrapyard_defs

import "core:fmt"
import a "godot:authoring"
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
        status = status_reference(ctx, cast(gd.Resource)source.status, fmt.tprintf("%s.status", path)),
    }
    scenegd.bake_fields(
        ctx,
        source,
        &result,
        []a.Field {
            a.integer("cooldown", 1, 3600),
            a.number("range", 0, 1000),
            a.number("radius", 0, 1000),
            a.number("arc_cos", -1, 1),
            a.number("speed", 1, 100),
            a.integer("dmg", 0, 255, "damage"),
            a.field("self_buff"),
            a.integer("duration", 0, 36000),
            a.integer("pulse", 1, 600),
        },
        path,
    )

    if source.turret != nil {
        turret := scenegd.bake_resource(ctx, cast(gd.Resource)source.turret, TurretDef, fmt.tprintf("%s.turret", path))

        if turret == nil {
            return 0, {}
        }

        scenegd.bake_fields(
            ctx,
            turret,
            &result.turret,
            []a.Field {
                a.integer("ammo", 1, 1000),
                a.integer("cadence", 1, 120),
                a.integer("damage", 1, 100),
                a.number("speed", 0, 100),
                a.integer("ttl", 1, 600),
                a.number("use_radius", 24, 96),
            },
            fmt.tprintf("%s.turret", path),
        )

        if !content.turret_valid(result.turret) {
            scenegd.bake_fail(ctx, fmt.tprintf("%s.turret", path), "invalid turret projectile or interaction radius")
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
