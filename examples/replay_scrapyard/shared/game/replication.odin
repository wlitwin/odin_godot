package scrapyard_game

import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"

PUBLIC_WORLD_POLICY :: u64(0x5253595055423031)

PUBLIC_PREDICTION :: u64(0x5253595052453031)

// Current entities are public. Rewind adjudication history belongs to the
// authority and its complete checkpoints, rather than every ordinary snapshot.
public_world :: proc(w: World) -> World {
    value := w
    value.hit_history = {}
    return value
}

public_replication :: proc() -> net.Replication(World, Control, Event, SEATS) {
    return {
        id = PUBLIC_WORLD_POLICY,
        project = proc(
            frame: r.Frame(World),
            held: [SEATS]Control,
            who: net.Recipient,
        ) -> (
            net.Replica(World, Control, SEATS),
            bool,
        ) {
            return {public_world(frame.state), held}, true
        },
        valid = proc(value: net.Replica(World, Control, SEATS), who: net.Recipient) -> bool {
            if !state_valid(value.state) || !reflect.equal(value.state.hit_history, World{}.hit_history) {
                return false
            }

            for c in value.held {
                if !control_valid(c) {
                    return false
                }
            }

            return true
        },
        event = proc(frame: r.Frame(World), who: net.Recipient, e: r.Occurrence(Event)) -> (Event, bool) {
            return e.value, true
        },
    }
}

// All visible actors remain in the prediction world. The group's remote
// controls are neutral; their displayed poses still use authority observations.
// Historical ray outcomes unavailable here remain unjudged until confirmation.
public_prediction :: proc() -> net.Prediction_Group(World) {
    return {id = PUBLIC_PREDICTION, project = proc(frame: r.Frame(World), seat: u16) -> World {
            return public_world(frame.state)
        }, valid = proc(w: World, seat: u16) -> bool {
            return seat > 0 && seat <= SEATS && state_valid(w)
        }}
}
