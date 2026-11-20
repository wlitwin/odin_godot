package duel

import v "godot:replay/view"

LOB_SLOT :: 2 * SEATS
BODY_COUNT :: LOB_SLOT + 64
CONTACTS :: v.Contact_Model(World, Event, 2, BODY_COUNT){body_poses, contact}

body_poses :: proc(w: ^World, bodies: ^v.Contact_Bodies(2, BODY_COUNT)) {
    for player, i in w.players {
        bodies.bodies[i] = {
            position = player.position,
            life     = u64(player.life),
            visible  = player.connected,
        }
        bodies.bodies[SEATS + i] = {
            position = player.drone,
            life     = u64(player.life),
            visible  = player.connected,
        }
    }
    for bullet, i in w.bullets.values {
        bodies.bodies[LOB_SLOT + i] = {
            position = bullet.position,
            life     = bullet.key,
            visible  = w.bullets.alive[i],
        }
    }
}

contact :: proc(e: Event) -> (c: v.Contact(2)) {
    if e.kind == .Lobbed || e.kind == .Landed {
        c.kind = e.kind == .Landed ? .Hit : .Motion
        c.subject = {LOB_SLOT + i32(e.slot), e.key, e.position}
        c.retires = e.kind == .Landed
    }
    return
}
