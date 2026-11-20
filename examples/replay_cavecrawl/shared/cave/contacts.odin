package cave

import v "godot:replay/view"

DWELLER_SLOT :: SEATS
ROCK_SLOT :: DWELLER_SLOT + 16
BODY_COUNT :: ROCK_SLOT + 64

CONTACTS :: v.Contact_Model(World, Event, 2, BODY_COUNT){contact_bodies, read_contact}
read_contact :: proc(e: Event) -> v.Contact(2) {return e.contact}

contact_group :: proc(w: ^World) -> u64 {return u64(w.seed) << 8 | u64(w.depth)}
player_life :: proc(p: Player) -> u64 {
    // Death keeps the final body in place. Respawn starts a new path.
    return u64(p.deaths - (p.hp <= 0 && p.deaths > 0 ? 1 : 0)) + 1
}
contact_bodies :: proc(w: ^World, out: ^v.Contact_Bodies(2, BODY_COUNT)) {
    out.group = contact_group(w)
    for p, i in w.players {out.bodies[i] = {
            position = p.position,
            life     = player_life(p),
            visible  = p.connected,
        }}
    for p, i in w.dwellers.values {
        out.bodies[DWELLER_SLOT + i] = {
            position = p.position,
            life     = u64(w.dwellers.generations[i]),
            visible  = w.dwellers.alive[i],
        }
    }
    for p, i in w.rocks.values {
        out.bodies[ROCK_SLOT + i] = {
            position = p.position,
            life     = u64(w.rocks.generations[i]),
            visible  = w.rocks.alive[i],
        }
    }
}
