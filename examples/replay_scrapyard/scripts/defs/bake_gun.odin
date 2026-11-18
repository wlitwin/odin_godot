package scrapyard_defs

import "core:fmt"
import a "godot:authoring"
import gd "godot:godot"
import content "../../shared/content"
import scenegd "godot:replay/godot/scene"

bake_gun :: proc(resource: gd.Resource, ctx: ^scenegd.Bake_Context, path: string) -> (u8, content.Gun) {
    source := scenegd.bake_resource(ctx, resource, GunDef, path)

    if source == nil {
        return 0, {}
    }

    id := scenegd.bake_integer(ctx, u8, source.id, 0, content.MAX_GUNS - 1, fmt.tprintf("%s.id", path))
    projectile := scenegd.bake_resource(
        ctx,
        cast(gd.Resource)source.projectile,
        ProjectileDef,
        fmt.tprintf("%s.projectile", path),
    )

    if projectile == nil {
        return 0, {}
    }

    result := content.Gun {
        name = content.name(gd.gd_string_to_odin(source.name)),
        family = scenegd.bake_integer(ctx, u8, source.kind, 0, 4, fmt.tprintf("%s.kind", path)),
    }
    scenegd.bake_fields(
        ctx,
        source,
        &result,
        []a.Field {
            a.integer("cooldown", 1, 240),
            a.integer("dmg", 0, 255, "damage"),
            a.integer("mag", 1, 65535, "mechanism.mag"),
            a.integer("reload_ticks", 1, 65535, "mechanism.reload_ticks"),
            a.integer("jam_per_mille", 0, 1000, "mechanism.jam_per_mille"),
            a.integer("jam_taps", 1, 255, "mechanism.jam_taps"),
        },
        path,
    )
    scenegd.bake_fields(
        ctx,
        projectile,
        &result,
        []a.Field{a.number("speed", 0, 100), a.integer("ttl", 1, 600)},
        fmt.tprintf("%s.projectile", path),
    )
    region := [4]f32{source.sprite_pos.x, source.sprite_pos.y, source.sprite_size.x, source.sprite_size.y}

    for value, i in region {
        if !content.finite(value) || value < 0 || value > 65535 || value != f32(u16(value)) {
            scenegd.bake_fail(
                ctx,
                fmt.tprintf("%s.sprite", path),
                "sprite coordinates must be nonnegative integers fitting u16",
            )
            return 0, {}
        }

        result.region[i] = u16(value)
    }

    if !content.gun_valid(result) {
        scenegd.bake_fail(ctx, path, "invalid gun or projectile values")
    }

    return id, result
}
