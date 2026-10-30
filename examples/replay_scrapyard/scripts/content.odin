package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import "defs"
import content "../shared/content"
import game "../shared/game"
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
	ref, report = scenegd.bake(&store, u8(0), game.CONTENT, content_extract)
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

content_extract :: proc(_: u8, ctx: ^scenegd.Bake_Context) -> content.Catalog {
	c: content.Catalog
	for category in ([5]string{"guns", "mobs", "status", "combos", "abilities"}) {
		seen: [256]bool
		batch: scenegd.Resource_Batch
		report := scenegd.resource_batch_load(&batch, fmt.tprintf("res://data/%s", category), 256)
		if report.error != .None {
			return content_error(ctx, d.report_path(&report), d.report_message(&report))
		}
		defer scenegd.resource_batch_destroy(&batch)
		for resource in batch.resources[:batch.count] {
			resource_path := gd.resource_get_path(resource)
			defer gd.free_string(resource_path)
			path := gd.gd_string_to_odin(resource_path)
			switch category {
			case "guns":
				id, value := defs.bake_gun(resource, ctx, path)
				if ctx.report.error != .None {
					return {}
				}
				if seen[id] {
					return content_error(ctx, path, "duplicate gun ID")
				}
				seen[id] = true
				c.guns[id] = value
				c.gun_count = max(c.gun_count, id + 1)
			case "mobs":
				id, value := defs.bake_mob(resource, ctx, path)
				if ctx.report.error != .None {
					return {}
				}
				if seen[id] {
					return content_error(ctx, path, "duplicate mob ID")
				}
				seen[id] = true
				c.mobs[id] = value
				c.mob_count = max(c.mob_count, id + 1)
			case "status":
				id, value := defs.bake_status(resource, ctx, path)
				if ctx.report.error != .None {
					return {}
				}
				if seen[id] {
					return content_error(ctx, path, "duplicate status ID")
				}
				seen[id] = true
				c.statuses[id] = value
				c.status_count = max(c.status_count, id + 1)
			case "combos":
				value := defs.bake_combo(resource, ctx, path)
				if ctx.report.error != .None {
					return {}
				}
				if c.combo_count >= content.MAX_COMBOS {
					return content_error(ctx, path, "too many combo definitions")
				}
				c.combos[c.combo_count] = value
				c.combo_count += 1
			case "abilities":
				id, value := defs.bake_ability(resource, ctx, path)
				if ctx.report.error != .None {
					return {}
				}
				if seen[id] {
					return content_error(ctx, path, "duplicate ability ID")
				}
				seen[id] = true
				c.abilities[id] = value
				c.ability_count = max(c.ability_count, id + 1)
			}

		}
	}
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
