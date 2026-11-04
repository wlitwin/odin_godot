package cave

import r "godot:replay"
import net "godot:replay/net"

// Match Kit's non-avatar orphan adoption: the previous host's carried prop
// moves to the successor, while every avatar keeps its returning identity.
observe_authority :: proc(w: ^World, authority: net.Authority_Observation, ctx: ^r.Step(Event)) {
    if w.authority_known &&
       w.authority_seat != authority.seat &&
       w.authority_seat != 0 &&
       w.relic.carrier == w.authority_seat {
        if w.relic.version == max(u32) {
            r.abort(ctx)
            return
        }

        w.relic.carrier = authority.seat
        w.relic.version += 1
        r.emit(ctx, 1000, 2, Event{kind = .Carry, position = w.relic.position, seat = authority.seat})
    }

    w.authority_known, w.authority_seat = true, authority.seat
}
