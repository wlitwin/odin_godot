package replay_scrapyard

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rt "godot:runtime"
import d "godot:replay/definitions"
import content "../shared/content"
import "defs"
import views "views"
import scenegd "godot:replay/godot/scene"

// A Resource per archetype connects authored gameplay identity to a local scene.
// Add a file here and a MobDef; no renderer fields or switch need changing.
enemy_archetypes_load :: proc(owner: ^scenegd.Archetype_Assets(content.Mob)) -> bool {
    catalog, ok := content_load()

    if !ok {
        return false
    }

    if !scenegd.archetype_assets_init(owner, content.MAX_MOBS) {
        return false
    }

    batch: scenegd.Resource_Batch
    defer scenegd.resource_batch_destroy(&batch)
    report := scenegd.resource_batch_load(&batch, "res://archetypes/enemies", content.MAX_MOBS)

    if report.error != .None {
        return content_report(&report)
    }

    values: [content.MAX_MOBS]d.Archetype(content.Mob, scenegd.Archetype_Visual)
    required: [content.MAX_MOBS]u32
    count, required_count := 0, 0

    for id in 0 ..< content.MAX_MOBS {
        if content.mob_present(&catalog, u8(id)) {
            required[required_count] = u32(id)
            required_count += 1
        }
    }

    for resource in batch.resources[:batch.count] {
        resource_path := gd.resource_get_path(resource)
        defer gd.free_string(resource_path)
        path := gd.gd_string_to_odin(resource_path)
        authored, problem := scenegd.resource_script(resource, views.ScrapEnemyArchetype, path)

        if problem.error != .None {
            return content_report(&problem)
        }

        definition := rt.script_of(cast(gd.Object)authored.definition, defs.MobDef)

        if definition == nil ||
           definition.id < 0 ||
           definition.id >= content.MAX_MOBS ||
           !content.mob_present(&catalog, u8(definition.id)) ||
           !views.enemy_style_valid(rt.script_of(cast(gd.Object)authored.appearance, views.ScrapEnemyStyle)) {
            gd.print_str(fmt.tprintf("RSY_ARCHETYPE_INVALID %s: missing/invalid MobDef or ScrapEnemyStyle", path))
            return false
        }

        // Definitions must reference the catalog's source directory, where the
        // shared extractor has already checked unique IDs and nested values.
        source := gd.resource_get_path(cast(gd.Resource)authored.definition)
        defer gd.free_string(source)
        source_path := gd.gd_string_to_odin(source)

        if !strings.has_prefix(source_path, "res://data/mobs/") ||
           strings.contains(strings.trim_prefix(source_path, "res://data/mobs/"), "/") {
            gd.print_str(fmt.tprintf("RSY_ARCHETYPE_INVALID %s: definition must reference data/mobs", path))
            return false
        }

        values[count] = {
            id = u32(definition.id),
            definition = catalog.mobs[definition.id],
            local = {cast(gd.Packed_Scene)authored.scene, cast(gd.Resource)authored.appearance},
        }
        count += 1
    }

    report = scenegd.archetype_assets_publish(owner, values[:count], required[:required_count])

    if report.error != .None {
        return content_report(&report)
    }

    return true
}
