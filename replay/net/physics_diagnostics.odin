package replay_net

import bd "godot:box3d/diagnostics"

// Encode a borrowed first confirmed-history divergence. This artifact is owned
// by Client, not a prediction-correction log; ordinary successful repairs never
// occupy this slot. The caller owns and must budget its output buffer.
client_physics_trace :: proc(c: ^Client($S, $C, $A, $E, $N), dst: []u8) -> (int, bd.Error) {
    if c.physics == nil {
        return 0, .Invalid
    }

    return bd.trace_encode(&c.physics.trace, dst)
}

client_physics_trace_clear :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    if c.physics == nil {
        return
    }

    bd.trace_destroy(&c.physics.trace)

    if c.physics.trace_charge != 0 {
        c.model.complete_codec.release(c.model.complete_codec.catalog, c.physics.trace_charge)
        c.physics.trace_charge = 0
    }
}

// Explicitly copied authoritative input record from the existing Timeline plus
// its bounded decision metadata. No solver image or execution is borrowed.
server_accepted_input :: proc(s: ^Server($S, $C, $A, $E, $N), tick: u64) -> (Accepted_Input(C, A, N), bool) {
    return server_accepted(s, tick)
}
