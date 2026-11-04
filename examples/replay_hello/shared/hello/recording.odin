package hello_game

import d "godot:replay/diagnostic"

// Manual replay contract revision, including step rules and immutable WALLS.
// Bump build when these change; content also matches the network scene contract.
RECORDING_CONTEXT :: d.Recording_Context {
    content = 0x5245504c41594831,
    build   = 1,
    tick_hz = 60,
}

recording_input_valid :: proc(input: Input) -> bool {
    for control in input.players {
        if !network_controls_valid(control) {
            return false
        }
    }

    return true
}

recording_model :: proc() -> d.Recording_Model(World, Input, Event) {
    return {step = step, state_valid = network_state_valid, input_valid = recording_input_valid}
}
