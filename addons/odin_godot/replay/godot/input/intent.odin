package replay_godot_input

import replaygd "godot:replay/godot"

import net "godot:replay/net"
import view "godot:replay/view"

session_intent :: proc(s: ^replaygd.Session($S, $C, $A, $E, $N), i: ^net.Action_Intent(A)) -> (u64, net.Error) {
    if !s.ready {
        return 0, .Not_Initialized
    }

    if s.recovery_serial != 0 {
        if error := net.intent_recover(i, s.recovery); error != .None {
            return 0, error
        }
    }

    if s.authority {
        return net.server_intent(&s.server, i)
    }

    return net.client_intent(&s.client, i)
}

room_intent :: proc(room: ^replaygd.Room($S, $C, $A, $E, $N), i: ^net.Action_Intent(A)) -> (u64, net.Error) {
    if !room.ready || room.handoff_requested || (room.phase != .Hosting && room.phase != .Following) {
        return 0, .Fenced
    }

    return session_intent(&room.session, i)
}

// Feed ordinary Session/Room presentation changes. Prediction, cancellation,
// another player's result and duplicate confirmations cannot settle a ticket.
intent_observe :: proc(
    i: ^net.Action_Intent($A),
    s: ^replaygd.Session($S, $C, A, $E, $N),
    change: view.Change(net.Net_Event(E)),
) -> bool {
    if s.recovery_serial != 0 && net.intent_recover(i, s.recovery) != .None {
        return false
    }

    seat := replaygd.session_seat(s)
    event := change.occurrence.value

    if seat == 0 ||
       event.kind != .Action_Result ||
       event.seat != seat ||
       change.kind == .Cancel ||
       (!change.confirmed && change.kind != .Confirm) {
        return false
    }

    return net.intent_resolve(
        i,
        change.occurrence.id.epoch,
        {event.sequence, change.occurrence.id.tick, event.applied, event.reason},
    )
}
