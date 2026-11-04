package scrapyard_defs

import "core:fmt"
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
        cooldown = scenegd.bake_integer(ctx, u16, source.cooldown, 1, 240, fmt.tprintf("%s.cooldown", path)),
        damage = scenegd.bake_integer(ctx, u8, source.dmg, 0, 255, fmt.tprintf("%s.dmg", path)),
        mechanism = {
            mag = scenegd.bake_integer(ctx, u16, source.mag, 1, 65535, fmt.tprintf("%s.mag", path)),
            reload_ticks = scenegd.bake_integer(
                ctx,
                u16,
                source.reload_ticks,
                1,
                65535,
                fmt.tprintf("%s.reload_ticks", path),
            ),
            jam_per_mille = scenegd.bake_integer(
                ctx,
                u16,
                source.jam_per_mille,
                0,
                1000,
                fmt.tprintf("%s.jam_per_mille", path),
            ),
            jam_taps = scenegd.bake_integer(ctx, u8, source.jam_taps, 1, 255, fmt.tprintf("%s.jam_taps", path)),
        },
        speed = projectile.speed,
        ttl = scenegd.bake_integer(ctx, u16, projectile.ttl, 1, 600, fmt.tprintf("%s.projectile.ttl", path)),
    }
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
