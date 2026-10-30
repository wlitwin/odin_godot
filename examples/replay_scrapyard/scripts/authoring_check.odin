//gd:extends Node2D
//gd:class ScrapAuthoringCheck
package replay_scrapyard

import "core:fmt"
import "core:strings"
import "core:encoding/json"
import gd "godot:godot"
import d "godot:replay/definitions"
import rgd "godot:replay/godot"
import r "godot:replay"
import v "godot:replay/view"
import "defs"
import content "../shared/content"
import game "../shared/game"
import display "../shared/presentation"
import views "views"

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

authoring_check :: proc(parent: gd.Node) -> Authoring_Report {
	result: Authoring_Report
	for category in ([5]string{"guns", "mobs", "status", "combos", "abilities"}) {
		batch: rgd.Resource_Batch
		defer rgd.resource_batch_destroy(&batch)
		report := rgd.resource_batch_load(&batch, fmt.tprintf("res://data/%s", category), 256)
		if report.error != .None {
			authoring_issue(&result, fmt.tprintf("res://data/%s", category), report)
			continue
		}
		seen: [256]bool
		for resource in batch.resources[:batch.count] {
			text := gd.resource_get_path(resource)
			defer gd.free_string(text)
			path := gd.gd_string_to_odin(text)
			ctx: rgd.Bake_Context
			id: u8
			switch category {
			case "guns":
				id, _ = defs.bake_gun(resource, &ctx, path)
			case "mobs":
				id, _ = defs.bake_mob(resource, &ctx, path)
			case "status":
				id, _ = defs.bake_status(resource, &ctx, path)
			case "combos":
				defs.bake_combo(resource, &ctx, path)
			case "abilities":
				id, _ = defs.bake_ability(resource, &ctx, path)
			}
			if ctx.report.error == .None && category != "combos" {
				if seen[id] {
					ctx.report = d.problem(.Invalid, path, "duplicate stable definition ID")
				}
				seen[id] = true
			}
			authoring_issue(&result, path, ctx.report)
			append(&result.definitions, Authoring_Definition{strings.clone(path), strings.clone(category), u32(id)})
		}
	}
	if len(result.issues) == 0 {
		store: d.Store(content.Catalog)
		defer d.destroy(&store)
		report := d.init(&store, 1)
		ref: d.Ref
		if report.error == .None {
			ref, report = rgd.bake(&store, u8(0), game.CONTENT, content_extract)
		}
		authoring_issue(&result, "res://data", report)
		if report.error == .None {
			result.catalog_digest = ref.content
		}
	}
	if len(result.issues) == 0 {
		assets: rgd.Archetype_Assets(content.Mob)
		defer rgd.archetype_assets_destroy(&assets)
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
			owner: rgd.Script_Archetypes(game.Mob, display.Mob_View, views.ScrapEnemyView, views.ScrapEnemyStyle)
			defer rgd.script_archetypes_destroy(&owner)
			report := rgd.script_archetypes_init(
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
						report = rgd.script_archetypes_present(&owner, {1, 1}, items[:])
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
	   rgd.storage_write(scrap_param("RSY_AUTHORING_REPORT", "user://authoring-report.json"), bytes, 1024 * 1024) !=
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
