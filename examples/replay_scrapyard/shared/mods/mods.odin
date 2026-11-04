package scrapyard_mods

import "core:encoding/json"
import "core:math"
import "core:mem"
import "core:fmt"
import c "../content"

MAX_FILE_BYTES :: 256 * 1024

SCRATCH_BYTES :: 4 * 1024 * 1024

Error :: enum {
    None,
    Size,
    JSON,
    Number,
    Index,
    Value,
    Capacity,
}

Counts :: struct {
    guns, mobs, status, combos, abilities: int,
}

Result :: struct {
    error: Error,
    counts: Counts,
}

// Authoring-only shapes. Floating numeric fields permit explicit range/integer
// checks before narrowing; these reference-bearing records never enter a world.
Gun :: struct {
    id, cooldown, dmg, mag, reload_ticks, jam_per_mille, jam_taps, ttl: f64,
    name, kind: string,
    speed: f32,
    sprite_pos, sprite_size: [2]f32,
}

Mob :: struct {
    id, hp, bite, boom_dmg, boom_status: f64,
    speed, body_r, scale, boom_radius: f32,
    prop: bool,
}

Status :: struct {
    id, duration, max_stacks, dot_dmg, dot_every: f64,
    name: string,
    move_mult, taken_mult, dealt_mult: f32,
    tint: [4]f32,
}

Combo :: struct {
    present, incoming, dmg, output: f64,
    reaction: string,
    radius: f32,
    consume: bool,
}

Ability :: struct {
    id, cooldown, dmg, status, duration, pulse: f64,
    name, family: string,
    range, radius, arc_cos, speed: f32,
    self_buff: bool,
}

File :: struct {
    guns: []Gun,
    mobs: []Mob,
    status: []Status,
    combos: []Combo,
    abilities: []Ability,
}

whole :: proc(value: f64) -> bool {
    return !math.is_nan(value) && !math.is_inf(value) && abs(value) <= 1000000000 && math.floor(value) == value
}

index_valid :: proc(value: f64, first, limit: int) -> bool {
    return whole(value) && value >= f64(first) && value < f64(limit)
}

// JSON5 matches the original authoring reader. A lexical depth gate (including
// quoted strings and comments) bounds recursive parser work before allocation.
bounded_text :: proc(bytes: []u8) -> bool {
    depth := 0
    quote := u8(0)
    escaped, line, block := false, false, false
    i := 0

    for i < len(bytes) {
        b := bytes[i]
        next := i + 1 < len(bytes) ? bytes[i + 1] : u8(0)

        if line {
            if b == '\n' || b == '\r' {
                line = false
            }

            i += 1
            continue
        }

        if block {
            if b == '*' && next == '/' {
                block = false
                i += 2
            } else {
                i += 1
            }

            continue
        }

        if quote != 0 {
            if escaped {
                escaped = false
            } else if b == '\\' {
                escaped = true
            } else if b == quote {
                quote = 0
            }

            i += 1
            continue
        }

        if b == '/' && next == '/' {
            line = true
            i += 2
            continue
        }

        if b == '/' && next == '*' {
            block = true
            i += 2
            continue
        }

        if b == '"' || b == '\'' {
            quote = b
        } else if b == '{' || b == '[' {
            depth += 1

            if depth > 32 {
                return false
            }
        } else if b == '}' || b == ']' {
            depth -= 1

            if depth < 0 {
                return false
            }
        }

        i += 1
    }

    return depth == 0 && quote == 0 && !block
}

apply :: proc(target: ^c.Catalog, bytes: []u8, allocator := context.allocator) -> Result {
    if len(bytes) == 0 || len(bytes) > MAX_FILE_BYTES || !bounded_text(bytes) {
        return {error = .Size}
    }

    scratch := make([]u8, SCRATCH_BYTES, allocator)
    defer delete(scratch, allocator)
    arena: mem.Arena
    mem.arena_init(&arena, scratch)
    file: File

    if json.unmarshal(bytes, &file, allocator = mem.arena_allocator(&arena)) != nil {
        return {error = .JSON}
    }

    if len(file.guns) > c.MAX_GUNS ||
       len(file.mobs) > c.MAX_MOBS ||
       len(file.status) > c.MAX_STATUS ||
       len(file.abilities) > c.MAX_ABILITIES ||
       len(file.combos) > c.MAX_COMBOS - int(target.combo_count) {
        return {error = .Capacity}
    }

    next := target^

    for g in file.guns {
        if !index_valid(g.id, 0, c.MAX_GUNS) {
            return {error = .Index}
        }

        for v in ([7]f64{g.cooldown, g.dmg, g.mag, g.reload_ticks, g.jam_per_mille, g.jam_taps, g.ttl}) {
            if !whole(v) {
                return {error = .Number}
            }
        }

        if g.cooldown > 240 || g.mag > 65535 || g.reload_ticks > 65535 || g.jam_taps > 255 || g.ttl > 600 {
            return {error = .Value}
        }

        region := [4]f32{g.sprite_pos[0], g.sprite_pos[1], g.sprite_size[0], g.sprite_size[1]}

        for v in region {
            if !c.finite(v) || v < 0 || v > 65535 || v != math.floor(v) {
                return {error = .Value}
            }
        }

        family := u8(0)

        switch g.kind {
        case "rivet":
            family = 1
        case "nade":
            family = 2
        case "lance":
            family = 3
        case "mend":
            family = 4
        }

        id := int(g.id)
        next.guns[id] = {
            name = c.name(g.name),
            family = family,
            cooldown = u16(max(g.cooldown, 1)),
            damage = u8(clamp(g.dmg, 0, 255)),
            mechanism = {
                u16(max(g.mag, 1)),
                u16(max(g.reload_ticks, 1)),
                u16(clamp(g.jam_per_mille, 0, 1000)),
                u8(max(g.jam_taps, 1)),
            },
            speed = g.speed,
            ttl = u16(max(g.ttl, 1)),
            region = {u16(region[0]), u16(region[1]), u16(region[2]), u16(region[3])},
        }

        if !c.gun_valid(next.guns[id]) {
            return {error = .Value}
        }

        next.gun_count = max(next.gun_count, u8(id + 1))
    }

    for m in file.mobs {
        if !index_valid(m.id, 0, c.MAX_MOBS) {
            return {error = .Index}
        }

        for v in ([4]f64{m.hp, m.bite, m.boom_dmg, m.boom_status}) {
            if !whole(v) {
                return {error = .Number}
            }
        }

        if m.hp > 65535 {
            return {error = .Value}
        }

        id := int(m.id)
        name := next.mobs[id].name

        if name.count == 0 {
            name = c.name(fmt.tprintf("mob %d", id))
        }

        next.mobs[id] = {
            name = name,
            hp = u16(max(m.hp, 1)),
            speed = m.speed,
            bite = u8(clamp(m.bite, 0, 255)),
            radius = m.body_r,
            scale = m.scale,
            prop = m.prop,
            boom_damage = u8(clamp(m.boom_dmg, 0, 255)),
            boom_radius = m.boom_radius,
            boom_status = u8(clamp(m.boom_status, 0, 254)),
        }

        if !c.mob_valid(next.mobs[id]) {
            return {error = .Value}
        }

        next.mob_count = max(next.mob_count, u8(id + 1))
    }

    for st in file.status {
        if !index_valid(st.id, 1, c.MAX_STATUS) {
            return {error = .Index}
        }

        for v in ([4]f64{st.duration, st.max_stacks, st.dot_dmg, st.dot_every}) {
            if !whole(v) {
                return {error = .Number}
            }
        }

        if st.duration > 36000 || st.dot_every > 600 {
            return {error = .Value}
        }

        id := int(st.id)
        next.statuses[id] = {
            name = c.name(st.name),
            duration = u16(max(st.duration, 1)),
            max_stacks = u8(clamp(st.max_stacks, 1, 9)),
            move_mult = st.move_mult,
            dot_damage = i8(clamp(st.dot_dmg, -128, 127)),
            dot_every = u16(max(st.dot_every, 0)),
            taken_mult = st.taken_mult,
            dealt_mult = st.dealt_mult,
            tint = st.tint,
        }

        if !c.status_valid(next.statuses[id]) {
            return {error = .Value}
        }

        next.status_count = max(next.status_count, u8(id + 1))
    }

    for ab in file.abilities {
        if !index_valid(ab.id, 1, c.MAX_ABILITIES) {
            return {error = .Index}
        }

        for v in ([5]f64{ab.cooldown, ab.dmg, ab.status, ab.duration, ab.pulse}) {
            if !whole(v) {
                return {error = .Number}
            }
        }

        if ab.cooldown > 3600 || ab.duration > 36000 || ab.pulse > 600 || ab.status < 0 || ab.status >= c.MAX_STATUS {
            return {error = .Value}
        }

        family := c.Ability_Family.Lob

        switch ab.family {
        case "cone":
            family = .Cone
        case "nova":
            family = .Nova
        case "buff":
            family = .Buff
        case "zone":
            family = .Zone
        }

        id := int(ab.id)
        next.abilities[id] = {
            name = c.name(ab.name),
            family = family,
            cooldown = u16(max(ab.cooldown, 1)),
            range = ab.range,
            radius = ab.radius,
            arc_cos = ab.arc_cos,
            speed = ab.speed,
            damage = u8(clamp(ab.dmg, 0, 255)),
            status = u8(ab.status),
            self_buff = ab.self_buff,
            duration = u16(max(ab.duration, 0)),
            pulse = u16(max(ab.pulse, 1)),
        }
        next.ability_count = max(next.ability_count, u8(id + 1))
    }

    for co in file.combos {
        if !index_valid(co.present, 1, c.MAX_STATUS) ||
           !index_valid(co.incoming, 1, c.MAX_STATUS) ||
           !index_valid(co.output, 0, c.MAX_STATUS) {
            return {error = .Index}
        }

        if !whole(co.dmg) {
            return {error = .Number}
        }

        reaction := c.Reaction.Detonate

        switch co.reaction {
        case "transmute":
            reaction = .Transmute
        case "spread":
            reaction = .Spread
        }

        next.combos[next.combo_count] = {
            present = u8(co.present),
            incoming = u8(co.incoming),
            reaction = reaction,
            damage = u8(clamp(co.dmg, 0, 255)),
            radius = co.radius,
            output = u8(co.output),
            consume = co.consume,
        }
        next.combo_count += 1
    }

    if !c.valid(next) {
        return {error = .Value}
    }

    target^ = next
    return {counts = {len(file.guns), len(file.mobs), len(file.status), len(file.combos), len(file.abilities)}}
}
