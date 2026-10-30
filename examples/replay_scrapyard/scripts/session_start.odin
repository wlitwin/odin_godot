package replay_scrapyard

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import rgd "godot:replay/godot"
import game "../shared/game"
import content "../shared/content"

open :: proc(self: ^ReplayScrapyard, role: rgd.Session_Role) {
	if self.session.ready {
		return
	}
	dash_reset(self)

	options: rgd.Session_Options
	if !configure_session_options(self, role, &options) {
		return
	}
	if !prepare_session_identity(self, role, &options) {
		return
	}
	configure_session_delivery(&options)

	world: game.World
	if !initialize_session_world(self, role, &world) {
		return
	}
	if err := open_session(self, world, options); err != .None {
		when gd.IS_WEB {
			if self.resume_requested {
				self.saved_run[0].phase = .Failed
				gd.set_string(
					cast(gd.Object)self.status,
					"text",
					"Could not resume this run. Saved data has not been changed.",
				)
				gd.print_str(fmt.tprintf("RSY_SAVE_ERROR resume=%v", err))
				return
			}
		}
		fail(self, fmt.tprintf("session %v", err))
		return
	}
	gd.set_string(cast(gd.Object)self.status, "text", fmt.ctprintf("Joining the yard at :%d", options.port))
}

configure_session_options :: proc(
	self: ^ReplayScrapyard,
	role: rgd.Session_Role,
	options: ^rgd.Session_Options,
) -> bool {
	options^ = rgd.SESSION_OPTIONS
	options.role = role
	if !rgd.session_assets_enable(options) {
		fail(self, "asset channel")
		return false
	}
	if !rgd.session_diagnostics_enable(options) {
		fail(self, "diagnostics channel")
		return false
	}
	if !rgd.session_comms_enable(options) {
		fail(self, "communications channel")
		return false
	}
	port := scrap_int("RSY_PORT", 49610)
	if port < 1 || port > 65535 {
		fail(self, "port")
		return false
	}
	options.port = u16(port)
	epoch := scrap_int("RSY_EPOCH", 1)
	if epoch < 1 {
		fail(self, "epoch")
		return false
	}
	options.network.epoch = u64(epoch)
	return true
}

// Browser identity/run reads may defer opening to a later frame. A failed read
// leaves the existing save intact and does not open a partially initialized game.
prepare_session_identity :: proc(
	self: ^ReplayScrapyard,
	role: rgd.Session_Role,
	options: ^rgd.Session_Options,
) -> bool {
	token, identity_ok := profile_open(&self.local_profile[0])
	if !identity_ok {
		when gd.IS_WEB {
			self.pending_open, self.pending_role = self.local_profile[0].waiting, role
			gd.set_string(
				cast(gd.Object)self.status,
				"text",
				self.pending_open ? "Loading saved profile…" : "Could not load your saved profile. Existing progress has not been changed.",
			)
			return false
		} else {
			fail(self, "profile/identity load")
			return false
		}
	}
	self.pending_open = false
	when gd.IS_WEB {
		if self.resume_requested && !browser_run_load_ready(self) {
			self.pending_open, self.pending_role = self.saved_run[0].phase != .Failed, role
			gd.set_string(
				cast(gd.Object)self.status,
				"text",
				self.pending_open ? "Loading saved run…" : "Could not resume this run. Saved data has not been changed.",
			)
			return false
		}
	}
	options.token = self.online.launch ? self.online.party.grant.token : token
	if self.local_profile[0].has_record && len(scrap_param("RSY_NAME", "")) == 0 {
		text := gd.new_string_odin(game.name_string(&self.local_profile[0].record.profile.name))
		gd.line_edit_set_text(self.name_edit, text)
		gd.free_string(text)
	}
	return true
}

configure_session_delivery :: proc(options: ^rgd.Session_Options) {
	options.latency_ms, options.jitter_ms = u32(scrap_int("RSY_LATENCY", 0)), u32(scrap_int("RSY_JITTER", 0))
	options.loss_permyriad, options.duplicate_permyriad =
		u32(scrap_int("RSY_LOSS", 0)), u32(scrap_int("RSY_DUPLICATE", 0))
	options.network.content, options.network.hz, options.network.snapshot_every, options.network.watch_delay =
		game.CONTENT, game.HZ, u32(clamp(scrap_int("RSY_SNAPSHOT_EVERY", 3), 1, 30)), 3
	options.remote_observed = true
	options.disable_lz4 = scrap_int("RSY_LZ4", 1) == 0
	options.disable_snapshot_erasure = scrap_int("RSY_FEC", 1) == 0
	options.disable_snapshot_shuffle = scrap_int("RSY_SHUFFLE", 1) == 0
	options.disable_action_copies = scrap_int("RSY_ACTION_COPIES", 1) == 0
	options.reuse_equal_corrections = scrap_int("RSY_REUSE_EQUAL", 0) == 1
}

initialize_session_world :: proc(self: ^ReplayScrapyard, role: rgd.Session_Role, world: ^game.World) -> bool {
	seed := u32(scrap_int("RSY_SEED", 1337))
	catalog, loaded := content_load()
	if loaded && self.development {
		catalog, loaded = authoring_ability_catalog(catalog, scrap_param("RSY_AUTHORING_ABILITY", ""))
	}
	if !loaded {
		fail(self, "content definitions")
		return false
	}
	if mods_enabled(self, role) {
		mods_load(&catalog)
	}
	if scrap_int("RSY_REQUIRE_STOCK", 0) == 1 && !reflect.equal(catalog, content.stock()) {
		fail(self, "stock resource comparison")
		return false
	}
	gd.print_str(
		fmt.tprintf(
			"RSY_CONTENT_LOADED guns=%d mobs=%d sum=%d",
			catalog.gun_count,
			catalog.mob_count,
			content.fingerprint(catalog),
		),
	)
	world^ = game.initial(seed, role == .Server, u8(clamp(scrap_int("RSY_MOBS", 8), 0, game.MAX_MOBS)))
	world.catalog = catalog
	configure_run_rules(world)
	configure_encounter(world)
	return true
}

configure_run_rules :: proc(world: ^game.World) {
	if scrap_int("RSY_RUN", 1) == 1 {
		world.rules = game.RUN_RULES
		world.rules.base_count = u16(clamp(scrap_int("RSY_WAVE_BASE", 10), 0, 1000))
		world.rules.growth = u16(clamp(scrap_int("RSY_WAVE_GROWTH", 4), 0, 20))
		world.rules.wave_count = u8(clamp(scrap_int("RSY_WAVES", 3), 1, 3))
		world.rules.rest = u16(clamp(scrap_int("RSY_REST", 300), 0, 36000))
		world.rules.barrels = u8(clamp(scrap_int("RSY_BARRELS", 5), 0, 32))
		world.boss_hp = u16(clamp(scrap_int("RSY_BOSS_HP", 0), 0, 65535))
	}
}

configure_encounter :: proc(world: ^game.World) {
	encounter := scrap_param("RSY_ENCOUNTER", "melee")
	switch encounter {
	case "mixed":
		world.encounter_kinds = {0, 1, 2, 3}
	case "boss":
		world.encounter_kinds = {4, 4, 4, 4}
		world.boss_hp = u16(clamp(scrap_int("RSY_BOSS_HP", 0), 0, 65535))
	case "spray":
		world.spawn_placed = true
		world.spawn_positions = {{500, 1040}, {620, 1040}, {740, 1040}, {860, 1040}}
	case "turret":
		world.spawn_placed = true
		world.encounter_count = 0
		world.spawn_positions = {{600, 1030}, {600, 1050}, {650, 1050}, {650, 1030}}
	case "stormcaller":
		world.spawn_placed, world.encounter_placed = true, true
		world.spawn_positions = {{500, 1040}, {700, 1040}, {500, 900}, {700, 900}}
		world.encounter_count, world.encounter_kinds = 1, {6, 6, 6, 6}
		world.encounter_positions = {{600, 1040}, {0, 0}, {0, 0}, {0, 0}}
		world.catalog.mobs[game.STORMCALLER].speed = 0 // fixed training encounter; ordinary waves use authored speed
	case "migration":
		world.spawn_placed, world.starting_hp = true, 8
		world.spawn_positions = {{500, 1040}, {600, 1040}, {500, 940}, {400, 1040}}
		world.encounter_count, world.encounter_placed, world.encounter_kinds = 2, true, {0, 0, 0, 0}
		world.encounter_positions = {{800, 1040}, {830, 1040}, {0, 0}, {0, 0}}
		world.catalog.mobs[0].hp, world.catalog.mobs[0].speed = 100, 0
		world.catalog.abilities[1].speed = 1
		world.catalog.abilities[5].duration = 1200
		if scrap_int("RSY_SLOW_BACKUP", 0) == 1 {
			world.spawn_positions[1] = {950, 1040}
			world.encounter_positions[0], world.encounter_positions[1] = {1100, 1040}, {1130, 1040}
			world.catalog.abilities[1].range = 800
		}
	case "abilities":
		world.spawn_placed, world.starting_hp = true, 8
		world.spawn_positions = {{685, 800}, {800, 660}, {620, 660}, {620, 800}}
		world.encounter_count, world.encounter_placed, world.encounter_kinds = 2, true, {0, 0, 0, 0}
		world.encounter_positions = {{800, 800}, {830, 800}, {0, 0}, {0, 0}}
		world.catalog.mobs[0].hp, world.catalog.mobs[0].speed = 100, 0
	case "barrels":
		world.encounter_count, world.encounter_placed, world.encounter_kinds = 3, true, {5, 5, 1, 0}
		world.encounter_positions = {{1050, 544}, {1110, 544}, {1170, 544}, {0, 0}}
	}
	gd.print_str(
		fmt.tprintf("RSY_ENCOUNTER kind=%s count=%d boss_hp=%d", encounter, world.encounter_count, world.boss_hp),
	)
}
