package replay_godot

import r "godot:replay"
import net "godot:replay/net"

// Small, copied metadata for an admitted world. This is a presentation scope,
// not permission to mutate authority state. It remains usable while fenced.
// Keep tracking per Session and reset it when that Session closes/reopens.
Presentation_Context :: struct {
    seat:                u16,
    epoch, reset:        u64,
    authority, observer: bool,
    correction_serial:   u64,
}

// A new correction does not itself reset the view's lifetime.
presentation_same_scope :: proc(a, b: Presentation_Context) -> bool {
    return(
        a.seat == b.seat &&
        a.epoch == b.epoch &&
        a.reset == b.reset &&
        a.authority == b.authority &&
        a.observer == b.observer \
    )
}

session_presentation :: proc(
    s: ^Session($State, $Control, $Action, $Event, $Seats),
) -> (
    view: Presentation_Context,
    ok: bool,
) {
    if s == nil {return}
    if r.owner_retains_access(&s.retained, .Execute) != .None || !s.ready || s.cleanup {return}
    if s.authority {
        if _, error := r.timeline_config(&s.server.timeline); error != .None {return}
        return {seat = s.server.local_seat, epoch = s.server.timeline.epoch, authority = true}, true
    }
    if !s.client.has_world || (s.client.phase != .Running && !s.client.recovering) {return}
    if _, error := r.timeline_config(&s.client.timeline); error != .None {return}
    return {
            seat = s.client.seat,
            epoch = s.client.timeline.epoch,
            reset = s.client.view_reset,
            observer = s.client.spectator,
            correction_serial = s.client.model.complete_state ? 0 : s.client.correction.serial,
        },
        true
}

// Read the latest value-prediction correction for this exact scope/serial.
// Reads do not consume it: camera and actor views can track it independently.
// Frames are copied only here, never by session_presentation. Several corrections
// in one pump may replace each other; this is deliberately not an event queue.
session_correction :: proc(
    s: ^Session($State, $Control, $Action, $Event, $Seats),
    expected: Presentation_Context,
    dst: ^net.State_Correction(State),
) -> bool {
    if dst == nil || expected.correction_serial == 0 {return false}
    current, ready := session_presentation(s)
    if !ready || current.authority || current != expected {return false}
    dst^ = s.client.correction
    return true
}
