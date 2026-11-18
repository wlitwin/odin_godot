package scrapyard_defs

import "core:fmt"
import a "godot:authoring"
import gd "godot:godot"
import content "../../shared/content"
import scenegd "godot:replay/godot/scene"

// One explicit mapping for game admission, export, archetypes and previews.
// The mapping supplies game bounds; Resource/Inspector metadata never guesses it.
bake_mob :: proc(resource: gd.Resource, ctx: ^scenegd.Bake_Context, path: string) -> (u8, content.Mob) {
    source := scenegd.bake_resource(ctx, resource, MobDef, path)

    if source == nil {
        return 0, {}
    }

    id := scenegd.bake_integer(ctx, u8, source.id, 0, content.MAX_MOBS - 1, fmt.tprintf("%s.id", path))
    result := content.Mob {
        name = content.name(gd.gd_string_to_odin(source.name)),
        boom_status = status_reference(ctx, cast(gd.Resource)source.boom_status, fmt.tprintf("%s.boom_status", path)),
    }
    scenegd.bake_fields(
        ctx,
        source,
        &result,
        []a.Field {
            a.integer("hp", 1, 65535),
            a.integer("bite", 0, 255),
            a.number("speed", 0, 1000),
            a.number("body_r", 0, 200, "radius"),
            a.number("scale", 0, 20),
            a.field("prop"),
            a.integer("boom_dmg", 0, 255, "boom_damage"),
            a.number("boom_radius", 0, 1000),
        },
        path,
    )

    if source.pulse != nil {
        pulse := scenegd.bake_resource(ctx, cast(gd.Resource)source.pulse, PulseDef, fmt.tprintf("%s.pulse", path))

        if pulse == nil {
            return 0, {}
        }

        scenegd.bake_fields(
            ctx,
            pulse,
            &result.pulse,
            []a.Field {
                a.integer("windup_ticks", 1, 180, "windup"),
                a.integer("cooldown_ticks", 30, 3600, "cooldown"),
                a.number("radius", 32, 400),
                a.integer("damage", 1, 20),
            },
            fmt.tprintf("%s.pulse", path),
        )

        if !content.pulse_valid(result.pulse) {
            scenegd.bake_fail(
                ctx,
                fmt.tprintf("%s.pulse", path),
                "invalid pulse ranges; radius must be finite and 32..400",
            )
        }
    }

    if !content.mob_valid(result) {
        scenegd.bake_fail(ctx, path, "invalid mob values")
    }

    return id, result
}
