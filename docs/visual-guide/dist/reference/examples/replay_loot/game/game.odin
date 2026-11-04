package loot

// A complete engine-free gameplay model for the first Replay experiment.
// Two players contest one chest and fire short-lived projectiles. Every mutable
// gameplay value, including allocation and RNG, is inside World.
import r "godot:replay"

Kind :: enum u8 {
    Chest,
    Projectile,
}

Entity :: struct {
    kind:  Kind,
    x:     i32,
    items: u32,
    ttl:   u16,
}

Player :: struct {
    x:   i32,
    bag: u32,
}

World :: struct {
    players:  [2]Player,
    entities: r.Pool(Entity, 16),
    chest:    r.Handle(Entity),
    rng:      r.Rng,
}

Controls :: struct {
    move: i8,
    take: bool,
    fire: bool,
    seq:  u32,
}

// Fixed seat order defines conflict resolution for this experiment. A network
// driver must authenticate and assemble this batch; it is not a packet format.
Input :: struct {
    players: [2]Controls,
}

Event_Kind :: enum u8 {
    Item_Taken,
    Fired,
}

Event :: struct {
    kind:   Event_Kind,
    player: u8,
    x:      i32,
    amount: u32,
}

Timeline :: r.Timeline(World, Input, Event)

initial :: proc() -> World {
    w := World {
        players = {{x = -1}, {x = 1}},
        rng     = r.rng_make(1337),
    }
    w.chest, _ = r.pool_insert(&w.entities, Entity{kind = .Chest, items = 5})
    return w
}

step :: proc(w: ^World, input: Input, ctx: ^r.Step(Event)) {
    // Stable slot order; spawning happens after the lifetime pass.
    for &entity, i in w.entities.values {
        if !w.entities.alive[i] || entity.kind != .Projectile {
            continue
        }

        entity.ttl -= 1

        if entity.ttl == 0 {
            r.pool_remove(&w.entities, r.Handle(Entity){u32(i), w.entities.generations[i]})
        }
    }

    for control, i in input.players {
        p := &w.players[i]
        p.x += i32(clamp(control.move, -1, 1))

        if control.take {
            if chest, found := r.pool_get(&w.entities, w.chest); found && abs(p.x - chest.x) <= 2 {
                amount := chest.items
                p.bag += amount
                r.pool_remove(&w.entities, w.chest)
                r.emit(ctx, u64(i + 1), u64(control.seq) << 8 | 1, Event{.Item_Taken, u8(i), p.x, amount})
            }
        }

        if control.fire {
            ttl := u16(2 + r.rng_next(&w.rng) % 3)

            if _, spawned := r.pool_insert(&w.entities, Entity{kind = .Projectile, x = p.x, ttl = ttl}); spawned {
                r.emit(ctx, u64(i + 1), u64(control.seq) << 8 | 2, Event{.Fired, u8(i), p.x, 1})
            }
        }
    }
}
