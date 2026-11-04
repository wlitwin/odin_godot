package replay_net

import h "godot:replay/history"

View_Query :: struct($T: typeid) {
    value:     T,
    status:    View_Status,
    tick:      u64,
    available: bool,
}

// Resolve the runner's validated view against frame-owned query history. This
// does not authenticate raw View_Stamps: use the View_Time supplied to step_view.
// Missing/expired/invalid historical views never fall back to the live value.
// blend must be pure and preserve the game's lifetime/discontinuity rules.
query_view :: proc(
    history: ^h.History($T, $N),
    view: View_Time,
    live: T,
    tick: u64,
    blend: proc(a, b: T, fraction: u16) -> T,
) -> View_Query(T) {
    result := View_Query(T) {
        status = view.status,
        tick   = tick,
    }

    switch view.status {
    case .Live:
        result.value, result.available = live, true
    case .Historical:
        if view.to < view.from || view.to > tick || blend == nil {
            result.status = .Invalid
            return result
        }

        a, b, found := h.bracket(history, view.from, view.to)

        if !found {
            result.status = .Unavailable
            return result
        }

        result.value, result.tick, result.available = blend(a, b, view.fraction), view.from, true
    case .Unavailable, .Expired, .Invalid:
    case:
        result.status = .Invalid
    }

    return result
}
