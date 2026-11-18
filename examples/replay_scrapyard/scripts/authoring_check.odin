//gd:extends Node2D
//gd:class ScrapAuthoringCheck
package replay_scrapyard

import "core:fmt"
import a "godot:authoring"
import "core:strings"
import "core:encoding/json"
import gd "godot:godot"
import d "godot:replay/definitions"
import r "godot:replay"
import v "godot:replay/view"
import "defs"
import content "../shared/content"
import game "../shared/game"
import display "../shared/presentation"
import views "views"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

ScrapAuthoringCheck :: struct {
    owner: gd.Node2d,
}

Authoring_Issue :: struct {
    source, path, message: string,
}

Authoring_Definition :: struct {
    source, category: string,
    id: u32,
}

Authoring_Report :: struct {
    ok: bool,
    issues: [dynamic]Authoring_Issue,
    definitions: [dynamic]Authoring_Definition,
    catalog_digest: u64,
}

authoring_issue :: proc(result: ^Authoring_Report, source: string, report: d.Report) {
    if report.error == .None {
        return
    }

    report := report
    append(
        &result.issues,
        Authoring_Issue {
            strings.clone(source),
            strings.clone(d.report_path(&report)),
            strings.clone(d.report_message(&report)),
        },
    )
}

// The same typed discovery and duplicate policy used by runtime admission.
// Semantic extraction continues across rows so the editor can show all issues.
authoring_category :: proc(
    result: ^Authoring_Report,
    $Script: typeid,
    category: string,
    capacity: int,
    extract: proc(_: gd.Resource, _: ^scenegd.Bake_Context, _: string) -> (u8, $Row),
    minimum_id := 0,
    id_field := "id",
) {
    directory := fmt.tprintf("res://data/%s", category)
    catalog: a.Catalog(Script)
    defer a.catalog_destroy(&catalog)
    report := a.catalog_load(&catalog, directory, capacity, minimum_id, id_field)
    if report.error != .None {
        source := a.report_path(&report)
        if id_field != "" {source = strings.trim_suffix(source, fmt.tprintf(".%s", id_field))}
        authoring_issue(result, source, scenegd.authoring_report(report))
        return
    }
    for entry in catalog.entries {
        ctx: scenegd.Bake_Context
        extract(entry.resource, &ctx, entry.path)
        authoring_issue(result, entry.path, ctx.report)
        append(
            &result.definitions,
            Authoring_Definition{strings.clone(entry.path), strings.clone(category), u32(entry.id)},
        )
    }
}

authoring_check :: proc(parent: gd.Node) -> Authoring_Report {
    result: Authoring_Report

    authoring_category(&result, defs.GunDef, "guns", content.MAX_GUNS, defs.bake_gun)
    authoring_category(&result, defs.MobDef, "mobs", content.MAX_MOBS, defs.bake_mob)
    authoring_category(&result, defs.StatusDef, "status", content.MAX_STATUS, defs.bake_status, 1)
    authoring_category(&result, defs.AbilityDef, "abilities", content.MAX_ABILITIES, defs.bake_ability, 1)
    authoring_category(
        &result,
        defs.ComboDef,
        "combos",
        content.MAX_COMBOS,
        proc(resource: gd.Resource, ctx: ^scenegd.Bake_Context, path: string) -> (u8, content.Combo) {
            return 0, defs.bake_combo(resource, ctx, path)
        },
        id_field = "",
    )

    if len(result.issues) == 0 {
        store: d.Store(content.Catalog)
        defer d.destroy(&store)
        report := d.init(&store, 1)
        ref: d.Ref

        if report.error == .None {
            ref, report = scenegd.bake(&store, u8(0), content.SEMANTIC, content_extract)
        }

        authoring_issue(&result, "res://data", report)

        if report.error == .None {
            result.catalog_digest = ref.content
        }
    }

    if len(result.issues) == 0 {
        assets: scenegd.Archetype_Assets(content.Mob)
        defer scenegd.archetype_assets_destroy(&assets)

        if !enemy_archetypes_load(&assets) {
            authoring_issue(
                &result,
                "res://archetypes/enemies",
                d.problem(
                    .Invalid,
                    "$archetypes",
                    "invalid or incomplete enemy registrations; inspect output for details",
                ),
            )
        } else {
            owner: scenegd.Script_Archetypes(game.Mob, display.Mob_View, views.ScrapEnemyView, views.ScrapEnemyStyle)
            defer scenegd.script_archetypes_destroy(&owner)
            report := scenegd.script_archetypes_init(
                &owner,
                &assets,
                parent,
                content.MAX_MOBS,
                proc(value: display.Mob_View) -> u32 {
                    return u32(value.kind)
                },
                views.scrap_enemy_view_replay_binding(),
            )
            authoring_issue(&result, "res://archetypes/enemies", report)

            if report.error == .None {
                for slot in assets.registry.entries {
                    if slot.present {
                        value := slot.value
                        items := [1]v.View_Item(game.Mob, display.Mob_View) {
                            {
                                handle = r.Handle(game.Mob){value.id, 1},
                                source = .Observed,
                                view = {
                                    scale = {1, 1},
                                    color = {1, 1, 1, 1},
                                    value = {
                                        kind = u8(value.id),
                                        hp = value.definition.hp,
                                        scale = value.definition.scale,
                                        tint = {1, 1, 1, 1},
                                        prop = value.definition.prop,
                                    },
                                },
                            },
                        }
                        report = scenegd.script_archetypes_present(&owner, {1, 1}, items[:])
                        text := gd.resource_get_path(value.local.scene)
                        authoring_issue(&result, gd.gd_string_to_odin(text), report)
                        gd.free_string(text)
                    }
                }
            }
        }
    }

    result.ok = len(result.issues) == 0
    return result
}

authoring_report_destroy :: proc(result: ^Authoring_Report) {
    for issue in result.issues {
        delete(issue.source)
        delete(issue.path)
        delete(issue.message)
    }

    for definition in result.definitions {
        delete(definition.source)
        delete(definition.category)
    }

    delete(result.issues)
    delete(result.definitions)
    result^ = {}
}

scrap_authoring_check_ready :: proc(self: ^ScrapAuthoringCheck) {
    result := authoring_check(self.owner)
    defer authoring_report_destroy(&result)
    bytes, error := json.marshal(result)
    defer delete(bytes)

    if error != nil ||
       storagegd.storage_write(
           scrap_param("REPLAY_AUTHORING_REPORT", "user://authoring-report.json"),
           bytes,
           1024 * 1024,
       ) !=
           .None {
        gd.print_str("RSY_AUTHORING_WRITE_FAILED")
        gd.scene_tree_quit(gd.get_tree(self.owner), 2)
        return
    }

    gd.print_str(
        fmt.tprintf(
            "RSY_AUTHORING_CHECK ok=%v issues=%d definitions=%d",
            result.ok,
            len(result.issues),
            len(result.definitions),
        ),
    )
    gd.scene_tree_quit(gd.get_tree(self.owner), result.ok ? 0 : 1)
}
