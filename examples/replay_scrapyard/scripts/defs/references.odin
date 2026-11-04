package scrapyard_defs

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import content "../../shared/content"
import scenegd "godot:replay/godot/scene"

// Author-facing Resource reference; simulation stores only the stable numeric ID.
// The catalog validates uniqueness/membership after all categories are extracted.
status_reference :: proc(
    ctx: ^scenegd.Bake_Context,
    resource: gd.Resource,
    path: string,
    required: bool = false,
) -> u8 {
    if resource == nil {
        if required {
            scenegd.bake_fail(ctx, path, "choose a StatusDef Resource")
        }

        return 0
    }

    status := scenegd.bake_resource(ctx, resource, StatusDef, path)

    if status == nil {
        return 0
    }

    source := gd.resource_get_path(resource)
    defer gd.free_string(source)
    text := gd.gd_string_to_odin(source)

    if !strings.has_prefix(text, "res://data/status/") ||
       strings.contains(strings.trim_prefix(text, "res://data/status/"), "/") ||
       strings.contains(text, "::") {
        scenegd.bake_fail(ctx, path, "StatusDef must reference a catalog Resource under data/status")
        return 0
    }

    return scenegd.bake_integer(ctx, u8, status.id, 1, content.MAX_STATUS - 1, fmt.tprintf("%s.id", path))
}
