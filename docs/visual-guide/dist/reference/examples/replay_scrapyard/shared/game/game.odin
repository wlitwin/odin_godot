package scrapyard_game

import "core:math"
import "core:unicode/utf8"
import r "godot:replay"
import h "godot:replay/history"
import net "godot:replay/net"
import view "godot:replay/view"
import p "godot:replay/play"
import content "../content"
import arena "../arena"
import assets "godot:replay/assets"

SEATS :: 4

CONTENT :: u64(0x525343524150304b)

HZ :: u32(60)

RUNNER_SPEED :: f32(220)

DASH_SPEED :: f32(840)

DASH_TICKS :: u64(10)

DASH_COOLDOWN :: u64(66)

LOOKS :: u8(3)

GUNS :: u8(7)

Name :: struct {
    count: u8,
    bytes: [31]u8,
}

Stage :: enum u8 {
    Staging,
    Yard,
    Clear,
    Over,
}

Meta :: struct {
    cores: u32,
    parts: u8,
}

Profile :: struct {
    meta: Meta,
    name: Name,
    look, iron: u8,
    abilities: [2]u8,
    ready: bool,
}

SPRAY_MAX :: 128 * 1024

Spray :: struct {
    image: assets.Ref,
    position: [2]f32,
    stamp: u32,
    floor: u8,
}

Player :: struct {
    connected, in_yard, meta_claimed: bool,
    generation, warp: u32,
    profile: Profile,
    spray: Spray,
    position, aim, dash_velocity: [2]f32,
    hp: u8,
    dash_until, dash_ready: u64,
    dashes: u32,
    gun: p.Gun_State,
    gun_id, parts, boost_damage, boost_rate, boost_speed: u8,
    revive: p.Channel,
    revives, purchases: u32,
    next_pull: u64,
    shots, damage, kills, scrap: u32,
    rail_queries, historical_queries, rejected_queries, healed, blasts: u32,
    last_query: net.View_Status,
    last_judged: u64,
    fx: [4]p.Effect,
    fx_credit: [4]Credit,
    cores: u32,
    ability_cd: [2]p.Cooldown,
    casts: u32,
    casts_by_ability: [content.MAX_ABILITIES]u32,
}

World :: struct {
    seed: u32,
    floor: u8,
    stage: Stage,
    run: u32,
    rules: Run_Rules,
    director: p.Director,
    waves: [3]p.Wave,
    wave_count: u8,
    spawn_index: u32,
    depart: p.Telegraph,
    over_until: u64,
    clears, descents, wipes: u32,
    host: u16,
    spawn_placed: bool,
    spawn_positions: [SEATS][2]f32,
    starting_hp: u8,
    clock, started_at: u64,
    layout: arena.Layout,
    players: [SEATS]Player,
    catalog: content.Catalog,
    encounter_count: u8,
    encounter_kinds: [4]u8,
    encounter_placed: bool,
    encounter_positions: [4][2]f32,
    boss_hp: u16,
    spits, pops, slams, adds, barrel_blasts, defeated, status_applied, status_refused, reactions, dot_pulses: u32,
    mobs: r.Pool(Mob, MAX_MOBS),
    lobs: r.Pool(Lob, MAX_LOBS),
    zones: r.Pool(Zone, MAX_ZONES),
    lobs_landed, zones_spawned, zone_pulses: u32,
    shots: r.Pool(Shot, MAX_SHOTS),
    drops: r.Pool(Drop, MAX_DROPS),
    hit_history: h.History([SEATS + MAX_MOBS]Proxy, 32) `replay:"authority"`,
    flashes: r.Pool(Flash, MAX_FLASHES),
    flash_evictions, visual_serial: u32,
    authority_epoch: u64,
    turrets: r.Pool(Turret, MAX_TURRETS),
}

// dash is retained for already-recorded scheduled controls in older saves.
// Current authored input submits Action.Dash and never sets this compatibility bit.
Control :: struct {
    move, aim: [2]f32,
    dash, fire, revive: bool,
}

Action_Kind :: enum u8 {
    Profile,
    Ready,
    Start,
    Cast,
    Buy,
    Workshop,
    Set_Spray,
    Stamp,
    Dev_Spawn,
    Dev_Edit,
    Dash,
    Turret_Mount,
    Turret_Dismount,
}

Action :: struct {
    kind: Action_Kind,
    profile: Profile,
    ready: bool,
    slot: u8,
    aim: [2]f32,
    aim_is_point: bool,
    item: u8,
    image: assets.Ref,
    development: Development,
    turret: r.Handle(Turret),
}

Event_Kind :: enum u8 {
    Started,
    Entered,
    Dash,
    Shot,
    Jam,
    Hit,
    Killed,
    Hurt,
    Pickup,
    Healed,
    Blast,
    Wall,
}

Event :: struct {
    kind: Event_Kind,
    seat: u16,
    generation: u32,
    serial: u32,
    position: [2]f32,
    detail: u8,
}

name :: proc(text: string) -> Name {
    result: Name
    result.count = u8(min(len(text), len(result.bytes)))

    for result.count > 0 && !utf8.valid_string(text[:result.count]) {
        result.count -= 1
    }

    copy(result.bytes[:result.count], transmute([]u8)text[:result.count])
    return result
}

name_string :: proc(value: ^Name) -> string {
    return string(value.bytes[:value.count])
}

name_valid :: proc(value: Name) -> bool {
    value := value

    if value.count > u8(len(value.bytes)) {
        return false
    }

    if !utf8.valid_string(string(value.bytes[:value.count])) {
        return false
    }

    for b, i in value.bytes {
        if i < int(value.count) {
            if b < 32 || b == 127 {
                return false
            }
        } else if b != 0 {
            return false
        }
    }

    return true
}

profile_valid :: proc(p: Profile) -> bool {
    return(
        p.meta.parts & ~u8(15) == 0 &&
        name_valid(p.name) &&
        p.look < LOOKS &&
        p.iron < content.MAX_GUNS &&
        p.abilities[0] < content.MAX_ABILITIES &&
        p.abilities[1] < content.MAX_ABILITIES \
    )
}

spray_ref_valid :: proc(ref: assets.Ref) -> bool {
    return ref == (assets.Ref{}) || assets.ref_valid(ref) && ref.bytes <= SPRAY_MAX
}

spawn :: proc(seat: u16) -> [2]f32 {
    return {arena.WIDTH / 2 + f32(int(seat) % 8) * 40 - 160, arena.HEIGHT / 2}
}

initial :: proc(seed: u32 = 1337, dedicated: bool = false, encounter_count: u8 = 8) -> World {
    w := World {
        seed = seed,
        floor = 1,
        host = dedicated ? 0 : 1,
        layout = arena.generate(seed, 1),
        catalog = content.stock(),
        encounter_count = encounter_count,
        encounter_kinds = {0, 0, 0, 1},
        starting_hp = 10,
    }

    for &player, i in w.players {
        player = fresh_player(u16(i + 1), 1)
        p.gun_equip(&player.gun, w.catalog.guns[player.gun_id].mechanism)
    }

    return w
}

fresh_player :: proc(seat: u16, generation: u32) -> Player {
    return {
        generation = generation,
        profile = {look = u8(seat) % LOOKS, iron = u8(seat - 1) % GUNS, abilities = {1, 2}},
        position = spawn(seat),
        aim = {1, 0},
        hp = 10,
        gun_id = u8(seat - 1) % GUNS,
    }
}

control_valid :: proc(c: Control) -> bool {
    for value in c.move {
        if math.is_nan(value) || math.is_inf(value) || abs(value) > 1 {
            return false
        }
    }

    for value in c.aim {
        if math.is_nan(value) || math.is_inf(value) || abs(value) > 1 {
            return false
        }
    }

    return true
}

state_valid :: proc(w: World) -> bool {
    value := w
    return state_valid_borrowed(&value)
}

// Synchronous borrowed read; never retain or mutate the world.
@(private)
state_valid_borrowed :: proc(w: ^World) -> bool {
    if w.starting_hp == 0 ||
       w.starting_hp > 10 ||
       w.floor == 0 ||
       w.stage > .Over ||
       w.host > SEATS ||
       !arena.valid(w.layout, w.seed, w.floor) ||
       !content.valid(w.catalog) ||
       w.encounter_count > MAX_MOBS {
        return false
    }

    for player in w.players {
        if player.generation == 0 ||
           !profile_valid(player.profile) ||
           player.hp > max_health(player.parts) ||
           !content.gun_present(&w.catalog, player.profile.iron) {
            return false
        }

        if !spray_ref_valid(player.spray.image) ||
           player.spray.stamp != 0 && (player.spray.floor != w.floor || !position_valid(player.spray.position)) {
            return false
        }

        if player.position[0] < arena.MARGIN ||
           player.position[0] > arena.WIDTH - arena.MARGIN ||
           player.position[1] < arena.MARGIN ||
           player.position[1] > arena.HEIGHT - arena.MARGIN {
            return false
        }

        for value in player.position {
            if math.is_nan(value) || math.is_inf(value) {
                return false
            }
        }

        for value in player.aim {
            if math.is_nan(value) || math.is_inf(value) || abs(value) > 1 {
                return false
            }
        }

        for value in player.dash_velocity {
            if math.is_nan(value) || math.is_inf(value) || abs(value) > DASH_SPEED {
                return false
            }
        }

        if w.stage == .Staging && player.in_yard {
            return false
        }
    }

    if w.spawn_placed {
        for point in w.spawn_positions {
            if !position_valid(point) ||
               point[0] < arena.MARGIN ||
               point[0] > arena.WIDTH - arena.MARGIN ||
               point[1] < arena.MARGIN ||
               point[1] > arena.HEIGHT - arena.MARGIN {
                return false
            }
        }
    }

    return combat_valid_borrowed(w) && abilities_valid_borrowed(w) && run_valid_borrowed(w) && turrets_valid(w)
}

model :: proc() -> net.Model(World, Control, Action, Event, SEATS) {
    return {
        step_view = step_view,
        action = action,
        reset_player = reset_player,
        control_valid = control_valid,
        replication = public_replication(),
        group = public_prediction(),
        action_schedule = dash_schedule(),
        authority = succession_policy(),
        action_valid = action_valid,
        state_valid = state_valid,
        action_admit = proc(user: rawptr, seat: u16, a: Action) -> bool {
            return development_allowed(false, 0, seat, a)
        },
        hold = proc(c: Control) -> Control {
            return {move = c.move, aim = c.aim, fire = c.fire, revive = c.revive}
        },
        event_owner = proc(e: Event) -> u16 {
            return e.seat
        },
        event_policy = proc(e: Event) -> view.Policy {
            return (e.kind == .Dash || e.kind == .Shot || e.kind == .Jam) ? .Speculative : .Confirmed
        },
    }
}

dash_schedule :: proc() -> net.Action_Schedule(Action) {
    return {id = 0x5253594143543032, timing = proc(a: Action) -> net.Action_Timing {
            return (a.kind == .Dash || a.kind == .Turret_Mount || a.kind == .Turret_Dismount) ? .Receipt : .Scheduled
        }}
}

dash_start :: proc(w: ^World, seat: u16, direction: [2]f32, ctx: ^r.Step(Event), after_step: bool = false) -> bool {
    player := &w.players[seat - 1]

    if !player.connected ||
       !player.in_yard ||
       player.hp == 0 ||
       turret_operator(w, seat) ||
       ctx.tick < player.dash_ready {
        return false
    }

    if player.dashes == max(u32) || ctx.tick > max(u64) - DASH_COOLDOWN {
        r.abort(ctx)
        return false
    }

    direction := direction

    if direction == ([2]f32{}) {
        direction = player.aim
    }

    n := math.sqrt(direction[0] * direction[0] + direction[1] * direction[1])

    if n <= 0 {
        return false
    }

    player.dash_velocity = direction / n * DASH_SPEED
    // Actions run after the movement step. Preserve ten future movement ticks;
    // an imported legacy control begins movement in its current step instead.
    player.dash_until, player.dash_ready = ctx.tick + DASH_TICKS + u64(after_step), ctx.tick + DASH_COOLDOWN
    player.dashes += 1
    r.emit(
        ctx,
        u64(player.generation) << 32 | u64(seat),
        u64(Event_Kind.Dash),
        Event{.Dash, seat, player.generation, player.dashes, player.position, 0},
    )
    return true
}

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    generation := w.players[seat - 1].generation
    turret_release_player(w, seat)

    if generation == max(u32) {
        r.abort(ctx)
        return
    }

    w.players[seat - 1] = fresh_player(seat, generation + 1)
}

enter :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    player := &w.players[seat - 1]

    if player.in_yard {
        return
    }

    if player.warp == max(u32) {
        r.abort(ctx)
        return
    }

    player.warp += 1
    player.in_yard, player.position, player.hp =
        true,
        w.spawn_placed ? w.spawn_positions[seat - 1] : spawn(seat),
        max_health(player.parts) == 10 ? w.starting_hp : max_health(player.parts)
    player.gun_id = player.profile.iron

    if p.gun_equip(
           &player.gun,
           w.catalog.guns[player.gun_id].mechanism,
           u32(seat) * 2654435761 + u32(w.floor) * 2246822519,
       ) !=
       .None {
        r.abort(ctx)
        return
    }

    r.emit(
        ctx,
        u64(player.generation) << 32 | u64(seat),
        u64(Event_Kind.Entered),
        Event{.Entered, seat, player.generation, 0, player.position, 0},
    )
}

all_ready :: proc(w: ^World) -> bool {
    count := 0

    for player in w.players {
        if player.connected {
            count += 1

            if !player.profile.ready {
                return false
            }
        }
    }

    return count > 0
}

start :: proc(w: ^World, ctx: ^r.Step(Event)) {
    w.stage, w.started_at = .Yard, ctx.tick
    r.emit(ctx, 100, u64(Event_Kind.Started), Event{kind = .Started})

    for player, i in w.players {
        if player.connected && player.profile.ready {
            enter(w, u16(i + 1), ctx)
        }
    }

    if w.rules.enabled {
        arm_floor(w, ctx, false)
    } else {
        encounter_start(w, ctx)
    }
}

action :: proc(w: ^World, seat: u16, a: Action, ctx: ^r.Step(Event)) -> bool {
    player := &w.players[seat - 1]

    if !player.connected {
        return false
    }

    switch a.kind {
    case .Turret_Mount:
        return turret_mount(w, seat, a.turret)
    case .Turret_Dismount:
        return turret_dismount(w, seat, a.turret)
    case .Dash:
        if !dash_start(w, seat, a.aim, ctx, after_step = true) {
            return false
        }
    case .Profile:
        if player.in_yard || !content.gun_present(&w.catalog, a.profile.iron) {
            return false
        }

        for id, slot in a.profile.abilities {
            if !content.ability_present(&w.catalog, id == 0 ? u8(slot + 1) : id) {
                return false
            }
        }

        if !player.meta_claimed {
            player.cores, player.parts, player.meta_claimed = a.profile.meta.cores, a.profile.meta.parts, true
        }

        player.profile = a.profile
        player.profile.meta = {player.cores, player.parts}

        for &id, slot in player.profile.abilities {
            if id == 0 {
                id = u8(slot + 1)
            }
        }
    case .Ready:
        player.profile.ready = a.ready

        if a.ready && w.stage != .Staging {
            enter(w, seat, ctx)
        }
    case .Start:
        if w.stage != .Staging || seat != w.host || !all_ready(w) {
            return false
        }

        start(w, ctx)
    case .Dev_Spawn:
        if w.stage == .Staging || a.slot >= SEATS || !w.players[a.slot].in_yard {
            return false
        }

        anchor := w.players[a.slot].position
        point := [2]f32 {
            clamp(anchor[0] + a.aim[0], 40, arena.WIDTH - 40),
            clamp(anchor[1] + a.aim[1], 40, arena.HEIGHT - 40),
        }

        if !spawn_mob(w, a.item, point) {
            return false
        }
    case .Dev_Edit:
        return development_apply(w, seat, a.development, ctx)
    case .Set_Spray:
        player.spray.image = a.image
    case .Stamp:
        if !player.in_yard || player.spray.stamp == max(u32) {
            return false
        }

        player.spray.position, player.spray.floor = player.position, w.floor
        player.spray.stamp += 1
    case .Buy:
        if !buy(w, seat, a.item, ctx) {
            return false
        }
    case .Workshop:
        if !workshop(w, seat, a.item) {
            return false
        }
    case .Cast:
        if !cast_ability(w, seat, a.slot, a.aim, a.aim_is_point, ctx) {
            return false
        }
    }

    h.record(&w.hit_history, ctx.tick, proxies(w))
    return true
}

step :: proc(w: ^World, controls: [SEATS]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    views: [SEATS]net.View_Time

    for &view in views {
        view = {ctx.tick, ctx.tick, 0, .Live}
    }

    step_view(w, controls, views, joins, leaves, ctx)
}

step_view :: proc(
    w: ^World,
    controls: [SEATS]Control,
    views: [SEATS]net.View_Time,
    joins, leaves: u64,
    ctx: ^r.Step(Event),
) {
    if ctx.tick > max(u64) - 65536 {
        r.abort(ctx)
        return
    }

    w.clock = ctx.tick
    feedback: Notices
    update_roster(w, joins, leaves)
    turret_cleanup(w)
    player_upkeep(w, &feedback, ctx)
    move_players(w, controls, ctx)

    if w.host == 0 && w.stage == .Staging && all_ready(w) {
        start(w, ctx)
    }

    if w.stage != .Staging {
        if w.rules.enabled && w.stage == .Yard {
            director_step(w, ctx)
        }

        revive_step(w, controls, &feedback, ctx)
        combat_step(w, controls, views, &feedback, ctx)

        if w.rules.enabled {
            run_step(w, ctx)
        }
    }

    turret_cleanup(w)
    flush(w, &feedback, ctx)
    h.record(&w.hit_history, ctx.tick, proxies(w))
}

update_roster :: proc(w: ^World, joins, leaves: u64) {
    for &player, i in w.players {
        if joins & (u64(1) << uint(i)) != 0 {
            player.connected = true
        }

        if leaves & (u64(1) << uint(i)) != 0 {
            player.connected, player.profile.ready = false, false
        }
    }

    // Lobby permission is replayable roster state, independent of transport
    // authority. Keep a connected leader; replace a departed leader in seat
    // order. Zero remains the dedicated server's automatic-start policy.
    if w.host != 0 && !w.players[w.host - 1].connected {
        for player, i in w.players {
            if player.connected {
                w.host = u16(i + 1)
                break
            }
        }
    }
}

move_players :: proc(w: ^World, controls: [SEATS]Control, ctx: ^r.Step(Event)) {
    for &player, i in w.players {
        if !player.connected || !player.in_yard || player.hp == 0 {
            continue
        }

        input := controls[i]

        if input.aim[0] != 0 || input.aim[1] != 0 {
            n := math.sqrt(input.aim[0] * input.aim[0] + input.aim[1] * input.aim[1])

            if n > 0.00001 {
                player.aim = input.aim / n
            }
        }

        if handle, mounted := turret_for(w, u16(i + 1)); mounted {
            t, _ := r.pool_get(&w.turrets, handle)
            t.aim = player.aim
            continue
        }

        if input.dash {
            dash_start(w, u16(i + 1), input.move, ctx)
        }

        velocity :=
            ctx.tick < player.dash_until ? player.dash_velocity : input.move * ((RUNNER_SPEED + f32(player.boost_speed) * 50) * status_multiplier(w, player.fx[:], .Move))
        player.position = arena.move(&w.layout, player.position, velocity, 1.0 / f32(HZ))
    }
}
