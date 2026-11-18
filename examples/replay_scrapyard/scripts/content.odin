package replay_scrapyard

import "core:fmt"
import a "godot:authoring"
import gd "godot:godot"
import "defs"
import content "../shared/content"
import d "godot:replay/definitions"
import scenegd "godot:replay/godot/scene"

// Resources are an authoring boundary. The resulting catalog owns only values;
// the host's complete catalog travels in world snapshots and recovery archives.
content_load :: proc() -> (content.Catalog, bool) {
    store: d.Store(content.Catalog)
    report := d.init(&store, 1)
    defer d.destroy(&store)

    if report.error != .None {
        return {}, content_report(&report)
    }

    ref: d.Ref
    ref, report = scenegd.bake(&store, u8(0), content.SEMANTIC, content_extract)

    if report.error != .None {
        return {}, content_report(&report)
    }

    return d.get(&store, ref)
}

content_report :: proc(report: ^d.Report) -> bool {
    gd.print_str(fmt.tprintf("RSY_CONTENT_INVALID %s: %s", d.report_path(report), d.report_message(report)))
    return false
}

content_error :: proc(ctx: ^scenegd.Bake_Context, path, message: string) -> content.Catalog {
    scenegd.bake_fail(ctx, path, message)
    return {}
}

// Each destination is part of a local candidate; no table becomes live until the
// complete catalog passes its cross-reference/semantic validator.
content_table :: proc(
    $Script: typeid,
    destination: []$Row,
    directory: string,
    ctx: ^scenegd.Bake_Context,
    extract: proc(_: gd.Resource, _: ^scenegd.Bake_Context, _: string) -> (u8, Row),
    minimum_id := 0,
) -> u8 {
    if ctx.report.error != .None {return 0}
    catalog: a.Catalog(Script)
    defer a.catalog_destroy(&catalog)
    ctx.report = scenegd.authoring_report(a.catalog_load(&catalog, directory, len(destination), minimum_id))
    if ctx.report.error != .None {return 0}
    for entry in catalog.entries {
        _, row := extract(entry.resource, ctx, entry.path)
        if ctx.report.error != .None {return 0}
        destination[entry.id] = row
    }
    return u8(catalog.high_water)
}

content_extract :: proc(_: u8, ctx: ^scenegd.Bake_Context) -> content.Catalog {
    c: content.Catalog
    c.gun_count = content_table(defs.GunDef, c.guns[:], "res://data/guns", ctx, defs.bake_gun)
    c.mob_count = content_table(defs.MobDef, c.mobs[:], "res://data/mobs", ctx, defs.bake_mob)
    c.status_count = content_table(defs.StatusDef, c.statuses[:], "res://data/status", ctx, defs.bake_status, 1)
    c.ability_count = content_table(defs.AbilityDef, c.abilities[:], "res://data/abilities", ctx, defs.bake_ability, 1)
    if ctx.report.error != .None {return {}}

    combos: a.Catalog(defs.ComboDef)
    defer a.catalog_destroy(&combos)
    ctx.report = scenegd.authoring_report(a.catalog_load(&combos, "res://data/combos", len(c.combos), id_field = ""))
    if ctx.report.error != .None {return {}}
    for entry in combos.entries {
        c.combos[entry.id] = defs.bake_combo(entry.resource, ctx, entry.path)
        if ctx.report.error != .None {return {}}
    }
    c.combo_count = u8(combos.high_water)
    if !content.valid(c) {
        return content_error(ctx, "$.catalog", "invalid catalog ranges, cross-references or combinations")
    }
    return c
}

// Explicit authoring admission, used only by an isolated development process
// before creating its Session. It never rewrites a live World or stock artifact.
authoring_ability_catalog :: proc(catalog: content.Catalog, path: string) -> (content.Catalog, bool) {
    if path == "" {
        return catalog, true
    }

    resource := gd.load(fmt.ctprintf("%s", path))

    if resource == nil {
        return {}, false
    }

    defer gd.release_ref(resource)
    ctx: scenegd.Bake_Context
    id, value := defs.bake_ability(resource, &ctx, path)

    if ctx.report.error != .None {
        content_report(&ctx.report)
        return {}, false
    }

    candidate := catalog
    candidate.abilities[id] = value
    candidate.ability_count = max(candidate.ability_count, id + 1)

    if !content.valid(candidate) {
        return {}, false
    }

    return candidate, true
}
