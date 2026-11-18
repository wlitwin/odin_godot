package scrapyard_defs

import "core:fmt"
import a "godot:authoring"
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
        tint = {source.tint.r, source.tint.g, source.tint.b, source.tint.a},
    }
    scenegd.bake_fields(
        ctx,
        source,
        &result,
        []a.Field {
            a.integer("duration", 1, 36000),
            a.integer("max_stacks", 1, 9),
            a.number("move_mult", 0, 4),
            a.integer("dot_dmg", -20, 20, "dot_damage"),
            a.integer("dot_every", 0, 600),
            a.number("taken_mult", 0, 4),
            a.number("dealt_mult", 0, 4),
        },
        path,
    )

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
    }
    scenegd.bake_fields(
        ctx,
        source,
        &result,
        []a.Field{a.integer("dmg", 0, 255, "damage"), a.number("radius", 0, 1000), a.field("consume")},
        path,
    )

    return result
}
