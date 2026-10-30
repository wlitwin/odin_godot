//gd:extends Node
//gd:class ScrapContentExport
package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import d "godot:replay/definitions"
import content "../shared/content"
import game "../shared/game"
import "defs"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

// Runs the exact extractor used by interactive play, including nested Resources.
ScrapContentExport :: struct {
	owner: gd.Node,
}

scrap_content_export_ready :: proc(self: ^ScrapContentExport) {
	gd.print_str(
		fmt.tprintf(
			"RSY_BAKE_CODE guard=%d catalog=%d",
			u32(#load_hash("odin_godot_guard.gen.odin", "crc32")),
			u32(#load_hash("../shared/content/content.odin", "crc32")),
		),
	)
	code := gd.Int(1)
	defer gd.scene_tree_quit(gd.get_tree(self.owner), code)
	store: d.Store(content.Catalog)
	report := d.init(&store, 1)
	defer d.destroy(&store)
	if report.error != .None {
		content_report(&report)
		return
	}
	ref: d.Ref
	ref, report = scenegd.bake(&store, u8(0), game.CONTENT, content_extract)
	if report.error == .None && scrap_param("RSY_AUTHORING_ABILITY", "") != "" {
		catalog, _ := d.get(&store, ref)
		candidate, ok := authoring_ability_catalog(catalog, scrap_param("RSY_AUTHORING_ABILITY", ""))
		if !ok {
			return
		}
		resource := gd.load(fmt.ctprintf("%s", scrap_param("RSY_AUTHORING_ABILITY", "")))
		defer gd.release_ref(resource)
		ctx: scenegd.Bake_Context
		id, _ := defs.bake_ability(resource, &ctx, "$selection")
		if ctx.report.error != .None {
			return
		}
		gd.print_str(fmt.tprintf("RSY_AUTHORING_SELECTED id=%d", id))
		d.remove(&store, ref)
		ref, report = d.publish(&store, candidate, game.CONTENT)
	}
	if report.error != .None {
		content_report(&report)
		return
	}
	bytes: []u8
	bytes, report = d.artifact_export(&store, ref, u64(scrap_int("RSY_BAKE_SOURCE", 0)))
	if report.error != .None {
		content_report(&report)
		return
	}
	defer delete(bytes)
	if storagegd.storage_write(scrap_param("RSY_BAKE_OUTPUT", "user://catalog.rpldef"), bytes, 1024 * 1024) != .None {
		gd.print_str("RSY_BAKE_WRITE_FAILED")
		return
	}
	gd.print_str(
		fmt.tprintf(
			"RSY_BAKE_OK semantic=%d schema=%d content=%d bytes=%d",
			ref.semantic,
			ref.schema,
			ref.content,
			len(bytes),
		),
	)
	code = 0
}
