package scrapyard_upgrade

import game "../game"
import r "godot:replay"
import p "godot:replay/play"
import h "godot:replay/history"
import arena "../arena"
import content "../content"

// Frozen canonical world shape for contents 42–45. Arc extends the Flash enum
// in content 46 without changing byte widths or offsets. Map fields explicitly.
Flash_45_Kind :: enum u8 {
	Lance,
	Mend,
	Boom,
	Reaction,
	Cast,
}

Flash_45 :: struct {
	kind: Flash_45_Kind,
	status, ability: u8,
	seat: u16,
	generation, serial: u32,
	origin, end: [2]f32,
	radius: f32,
	until: u64,
}

World_45 :: struct {
	seed: u32,
	floor: u8,
	stage: game.Stage,
	run: u32,
	rules: game.Run_Rules,
	director: p.Director,
	waves: [3]p.Wave,
	wave_count: u8,
	spawn_index: u32,
	depart: p.Telegraph,
	over_until: u64,
	clears, descents, wipes: u32,
	host: u16,
	spawn_placed: bool,
	spawn_positions: [game.SEATS][2]f32,
	starting_hp: u8,
	clock, started_at: u64,
	layout: arena.Layout,
	players: [game.SEATS]game.Player,
	catalog: Catalog_49,
	encounter_count: u8,
	encounter_kinds: [4]u8,
	encounter_placed: bool,
	encounter_positions: [4][2]f32,
	boss_hp: u16,
	spits, pops, slams, adds, barrel_blasts, defeated, status_applied, status_refused, reactions, dot_pulses: u32,
	mobs: r.Pool(game.Mob, game.MAX_MOBS),
	lobs: r.Pool(game.Lob, game.MAX_LOBS),
	zones: r.Pool(game.Zone, game.MAX_ZONES),
	lobs_landed, zones_spawned, zone_pulses: u32,
	shots: r.Pool(game.Shot, game.MAX_SHOTS),
	drops: r.Pool(game.Drop, game.MAX_DROPS),
	hit_history: h.History([game.SEATS + game.MAX_MOBS]game.Proxy, 32),
	flashes: r.Pool(Flash_45, game.MAX_FLASHES),
	flash_evictions, visual_serial: u32,
}

map_world :: proc(old: World_45) -> (game.World, bool) {
	value := game.World {
		seed = old.seed,
		floor = old.floor,
		stage = old.stage,
		run = old.run,
		rules = old.rules,
		director = old.director,
		waves = old.waves,
		wave_count = old.wave_count,
		spawn_index = old.spawn_index,
		depart = old.depart,
		over_until = old.over_until,
		clears = old.clears,
		descents = old.descents,
		wipes = old.wipes,
		host = old.host,
		spawn_placed = old.spawn_placed,
		spawn_positions = old.spawn_positions,
		starting_hp = old.starting_hp,
		clock = old.clock,
		started_at = old.started_at,
		layout = old.layout,
		players = old.players,
		catalog = catalog_current(old.catalog),
		encounter_count = old.encounter_count,
		encounter_kinds = old.encounter_kinds,
		encounter_placed = old.encounter_placed,
		encounter_positions = old.encounter_positions,
		boss_hp = old.boss_hp,
		spits = old.spits,
		pops = old.pops,
		slams = old.slams,
		adds = old.adds,
		barrel_blasts = old.barrel_blasts,
		defeated = old.defeated,
		status_applied = old.status_applied,
		status_refused = old.status_refused,
		reactions = old.reactions,
		dot_pulses = old.dot_pulses,
		mobs = old.mobs,
		lobs = old.lobs,
		zones = old.zones,
		lobs_landed = old.lobs_landed,
		zones_spawned = old.zones_spawned,
		zone_pulses = old.zone_pulses,
		shots = old.shots,
		drops = old.drops,
		hit_history = old.hit_history,
		flash_evictions = old.flash_evictions,
		visual_serial = old.visual_serial,
	}
	value.flashes.alive = old.flashes.alive
	value.flashes.generations = old.flashes.generations
	value.flashes.count = old.flashes.count
	for f, i in old.flashes.values {
		if f.kind > .Cast {
			return {}, false
		}
		value.flashes.values[i] = {
			game.Flash_Kind(f.kind),
			f.status,
			f.ability,
			f.seat,
			f.generation,
			f.serial,
			f.origin,
			f.end,
			f.radius,
			f.until,
		}
	}
	return value, true
}

state_45_valid :: proc(old: World_45) -> bool {
	value, ok := map_world(old)
	return ok && game.state_valid(value)
}
