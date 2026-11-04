// Observed input-history cursor only: no simulation, history or input mutation.
package accepted_audit

Scope :: struct {
    epoch, generation, serial, baseline: u64,
}

Gap :: struct {
    first, last: u64,
}

Error :: enum {
    None,
    Uncommitted_Scope,
    Invalid_Scope,
    Invalid_Cursor,
    Missing_Input,
}

// The caller supplies ONLY the current validated complete-Welcome scope.
// Initial/same-scope calls never move a cursor. A new monotone scope can make
// the interval through its actual baseline unavailable, never accepted rows.
begin :: proc(previous, current: Scope, cursor: u64, committed: bool) -> (u64, Gap, Error) {
    if !committed {
        return cursor, {}, .Uncommitted_Scope
    }

    if current.epoch == 0 || current.generation == 0 || current.serial == 0 {
        return cursor, {}, .Invalid_Scope
    }

    if previous == (Scope{}) {
        if cursor != current.baseline {
            return cursor, {}, .Invalid_Cursor
        }

        return cursor, {}, .None
    }

    if cursor < previous.baseline {
        return cursor, {}, .Invalid_Cursor
    }

    if previous == current {
        return cursor, {}, .None
    }

    if current.epoch != previous.epoch ||
       current.generation < previous.generation ||
       (current.generation == previous.generation && current.serial <= previous.serial) {
        return cursor, {}, .Invalid_Scope
    }

    if current.baseline < cursor {
        return cursor, {}, .Invalid_Cursor
    }

    if current.baseline == cursor {
        return cursor, {}, .None
    }

    return current.baseline, {cursor + 1, current.baseline}, .None
}

// A missing row is always fatal; it cannot advance a same/post-baseline audit.
record :: proc(cursor, tick: u64, found: bool) -> (u64, Error) {
    if !found {
        return cursor, .Missing_Input
    }

    if cursor == max(u64) || tick != cursor + 1 {
        return cursor, .Invalid_Cursor
    }

    return tick, .None
}

// Receipt provenance is optional and must describe the exact typed input that
// the Timeline retained. Stamps/controls alone cannot reconstruct origins.
origin_matches :: proc(committed, receipt: $Batch, found: bool) -> bool {
    return found && committed == receipt
}

Snapshot_Evidence :: struct {
    previous_catchups, current_catchups, first, last, head, confirmed, final, frame_tick: u64,
    window_valid, frame_found, has_input:                                                 bool,
}

// A validated canonical adoption can replace retained history with an anchor
// whose generating input was never imported. This is not an accepted row and
// does not authorize moving past any ordinary/post-anchor missing input.
snapshot_gap :: proc(cursor: u64, e: Snapshot_Evidence) -> (Gap, bool) {
    if e.current_catchups <= e.previous_catchups || !e.window_valid || !e.frame_found || e.has_input {
        return {}, false
    }

    if e.first > e.last || e.last != e.head || e.confirmed > e.head || e.final > e.confirmed {
        return {}, false
    }

    if e.frame_tick != e.first || e.first <= cursor || e.first > e.final {
        return {}, false
    }

    return {cursor + 1, e.first}, true
}
