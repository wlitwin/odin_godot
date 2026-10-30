package replay_scrapyard

import gd "godot:godot"
import r "godot:replay"
import content "../shared/content"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/game"
import display "../shared/presentation"
import views "views"

Combat_View_Key :: struct {
	run: u32,
	floor: u8,
}

Combat_Bridge :: struct {
	mobs: rgd.Script_Archetypes(game.Mob, display.Mob_View, views.ScrapEnemyView, views.ScrapEnemyStyle),
	drops: rgd.View_Pool2(game.Drop, u8, gd.Node2d),
	scope: v.Scope_Tracker(Combat_View_Key),
}

combat_bridge_init :: proc(self: ^ReplayScrapyard) -> bool {
	bridge := &self.combat_bridge[0]
	// Candidate registry is local: the view owner retains its own assets/config.
	assets: rgd.Archetype_Assets(content.Mob)
	defer rgd.archetype_assets_destroy(&assets)
	if !enemy_archetypes_load(&assets) {
		return false
	}
	report := rgd.script_archetypes_init(
		&bridge.mobs,
		&assets,
		self.world_node,
		game.MAX_MOBS,
		proc(value: display.Mob_View) -> u32 {
			return u32(value.kind)
		},
		views.scrap_enemy_view_replay_binding(),
	)
	if report.error != .None {
		combat_bridge_close(self)
		return content_report(&report)
	}
	if !rgd.view_pool_load(
		&bridge.drops,
		self.world_node,
		"res://entities/scrap.tscn",
		game.MAX_DROPS,
		rgd.View_Binding(u8, gd.Node2d) {
			attach = proc(_: rawptr, node: gd.Node2d) -> (gd.Node2d, bool) {
				gd.canvas_item_set_visible(node, true)
				return node, true
			},
			paint = proc(_: rawptr, node: ^gd.Node2d, value: u8) {
			},
		},
	) {
		combat_bridge_close(self)
		return false
	}
	return true
}

combat_bridge_close :: proc(self: ^ReplayScrapyard) {
	bridge := &self.combat_bridge[0]
	rgd.script_archetypes_destroy(&bridge.mobs)
	rgd.view_pool_destroy(&bridge.drops)
	bridge^ = {}
}

combat_bridge_paint :: proc(self: ^ReplayScrapyard, observed: game.World, dt: f64) {
	bridge := &self.combat_bridge[0]
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	reset := self.session.authority ? u64(0) : self.session.client.view_reset
	scope, error := v.scope_update(
		&bridge.scope,
		{epoch, reset, observed.clock},
		Combat_View_Key{observed.run, observed.floor},
		rewind_resets = true,
	)
	if error != .None {
		fail(self, "combat view scope")
		return
	}
	mobs := display.mobs(observed, epoch)
	drops := display.drops(observed)
	report := rgd.script_archetypes_present(&bridge.mobs, scope, mobs.items[:mobs.count])
	if report.error != .None {
		content_report(&report)
		fail(self, "combat view binding")
		return
	}
	if rgd.view_pool_present(&bridge.drops, scope, drops.items[:drops.count]) != .None {
		report = rgd.view_pool_problem(&bridge.drops)
		content_report(&report)
		fail(self, "drop view binding")
		return
	}
	rgd.script_archetypes_visit(&bridge.mobs, self, combat_enemy_notice)
}

// Game-specific notice policy stays here. Iteration and ownership are shared.
combat_enemy_notice :: proc(self: ^ReplayScrapyard, _: r.Handle(game.Mob), view: ^views.ScrapEnemyView) {
	impact := views.enemy_view_take_impact(view)
	if impact.ready {
		value := impact.value
		feedback_mob(
			self,
			{epoch = value.epoch, tick = value.tick, source = value.source, key = 0x100},
			game.Mob{hp = value.hp, position = value.position, kind = value.kind},
			impact.damage,
			value.prop,
		)
	}
}

@(gd_method)
replay_scrapyard_bridge_probe :: proc(self: ^ReplayScrapyard, key: string) -> gd.Int {
	bridge := &self.combat_bridge[0]
	if key == "scope" {
		return gd.Int(bridge.scope.revision)
	}
	if key == "drops" {
		return gd.Int(rgd.view_pool_stats(&bridge.drops).count)
	}
	stats := rgd.script_archetypes_stats(&bridge.mobs)
	switch key {
	case "mobs":
		return gd.Int(stats.count)
	case "created":
		return gd.Int(stats.created)
	case "retired":
		return gd.Int(stats.retired)
	case "paints":
		return gd.Int(stats.paints)
	case "skipped":
		return gd.Int(stats.skipped_paints)
	case "writes":
		return gd.Int(stats.property_writes)
	case "property_skips":
		return gd.Int(stats.property_skips)
	}
	return -1
}
