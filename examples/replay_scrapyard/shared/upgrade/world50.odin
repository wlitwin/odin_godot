package scrapyard_upgrade

import game "../game"
import content "../content"
import frozen "../revisions/content50"
import mapping "../upgrade_catalog"
import r "godot:replay"
import p "godot:replay/play"
import h "godot:replay/history"
import arena "../arena"

Catalog_50 :: frozen.Catalog_50

World_50 :: struct {
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
    catalog: Catalog_50,
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
    hit_history: h.History([game.SEATS + game.MAX_MOBS]game.Proxy, 32) `replay:"authority"`,
    flashes: r.Pool(game.Flash, game.MAX_FLASHES),
    flash_evictions, visual_serial: u32,
    authority_epoch: u64,
}

map_world_50 :: proc(old: World_50) -> (game.World, bool) {
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
        catalog = catalog_current_50(old.catalog),
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
        flashes = old.flashes,
        flash_evictions = old.flash_evictions,
        visual_serial = old.visual_serial,
        authority_epoch = old.authority_epoch,
    }
    return value, game.state_valid(value)
}

world_50 :: proc(old: game.World) -> World_50 {
    return {
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
        catalog = catalog_50(old.catalog),
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
        flashes = old.flashes,
        flash_evictions = old.flash_evictions,
        visual_serial = old.visual_serial,
        authority_epoch = old.authority_epoch,
    }
}

state_50_valid :: proc(w: World_50) -> bool {
    _, ok := map_world_50(w)
    return ok
}

catalog_current_50 :: proc(old: Catalog_50) -> content.Catalog {
    return mapping.from50(old)
}

catalog_50 :: proc(old: content.Catalog) -> Catalog_50 {
    return mapping.to50(old)
}
