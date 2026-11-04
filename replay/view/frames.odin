package replay_view

import "core:math"
import r "godot:replay"

// Copies two adjacent frames. The caller chooses the presentation clock and
// extracts only the poses it wants to interpolate. Membership and discrete state
// should come from the lower frame until the clock reaches the next tick.
// At the current head, hold that frame; never extrapolate past available state.
frames_at :: proc(
    t: ^r.Timeline($State, $Input, $Event),
    lower: u64,
    alpha: f32,
) -> (
    a, b: r.Frame(State),
    blend: f32,
    ok: bool,
) {
    if math.is_nan(alpha) || math.is_inf(alpha) {
        return
    }

    a, ok = r.read(t, lower)

    if !ok {
        return
    }

    if lower == t.head {
        return a, a, 0, true
    }

    b, ok = r.read(t, lower + 1)

    if !ok {
        return
    }

    return a, b, clamp(alpha, 0, 1), true
}
