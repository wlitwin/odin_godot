package replay_net

import "core:mem"
import "core:reflect"
import r "godot:replay"
import bd "godot:box3d/diagnostics"
import sc "godot:replay/schema"

ACCEPTED_PHYSICS_VERSION :: u32(1)
// Complete-physics wire revision, carried in every fact header. 2: steady
// state is accepted facts + small Physics_Status; complete images only for
// Welcome, explicit mismatch requests and spectators. Peers on another
// revision reject each other's facts instead of half-working.
PHYSICS_WIRE_VERSION :: u32(2)
PHYSICS_HISTORY :: 128
// Ceiling for a complete-physics runner's prediction/repair window
// (Config.max_prediction, max_future). Each side's active window is its
// configured max_prediction. Prediction depth must cover the round trip plus
// the input arrival reserve, so the ceiling sits well past ordinary RTTs.
PHYSICS_WINDOW :: 32
// Default window: 500 ms at 60 Hz, enough lead and confirmation lag for
// round trips up to roughly 400 ms before the client stalls.
PHYSICS_DEFAULT_WINDOW :: 30

Control_Origin :: enum u8 {
    Neutral,
    Sample,
    Held,
    Local,
}

Driver_Binding :: struct {
    generation, serial, incarnation: u64,
}

Accepted_Decisions :: struct($Seats: int) {
    origins:  [Seats]Control_Origin,
    drivers:  [Seats]Driver_Binding,
    applied:  [Seats]bool,
    verdicts: [Seats]Action_Reason,
}

// Authoritative values used by the existing callback, not a second simulation.
// Viewer generation/serial stay in the packet envelope, not this shared record.
Accepted_Input :: struct($Control, $Action: typeid, $Seats: int) {
    version:     u32,
    epoch, tick: u64,
    batch:       Batch(Control, Action, Seats),
    decisions:   Accepted_Decisions(Seats),
}

// A bounded knowledge ledger beside predicted inputs in the existing Timeline.
// It owns no solver/game frames and runs no simulation/rollback loop.
Accepted_Ledger :: struct($Control, $Action: typeid, $Seats: int) {
    allocator:               mem.Allocator,
    epoch, baseline, newest: u64,
    entries:                 []Accepted_Input(Control, Action, Seats),
}

accepted_ledger_init :: proc(
    ledger: ^Accepted_Ledger($C, $A, $N),
    epoch, baseline: u64,
    max_bytes: u64 = 8 * 1024 * 1024,
    allocator := context.allocator,
) -> Error {
    if len(ledger.entries) != 0 || epoch == 0 || N < 1 || N > 8 {
        return .Invalid_Config
    }

    if !r.value_supported(C) || !r.value_supported(A) {
        return .Invalid_Model
    }

    bytes := u64(size_of(Accepted_Input(C, A, N))) * PHYSICS_HISTORY

    if bytes > max_bytes {
        return .Capacity
    }

    ledger.allocator = allocator
    ledger.epoch = epoch
    ledger.baseline = baseline
    ledger.entries = make([]Accepted_Input(C, A, N), PHYSICS_HISTORY, allocator)
    return .None
}

accepted_ledger_destroy :: proc(ledger: ^Accepted_Ledger($C, $A, $N)) {
    delete(ledger.entries, ledger.allocator)
    ledger^ = {}
}

accepted_read :: proc(ledger: ^Accepted_Ledger($C, $A, $N), tick: u64) -> (Accepted_Input(C, A, N), bool) {
    if len(ledger.entries) != PHYSICS_HISTORY || tick == 0 {
        return {}, false
    }

    entry := ledger.entries[tick % PHYSICS_HISTORY]
    return entry, entry.version == ACCEPTED_PHYSICS_VERSION && entry.epoch == ledger.epoch && entry.tick == tick
}

// Separate validation makes a multi-entry packet atomic: validate every item and
// existing-slot conflict first, then store the already checked values together.
accepted_can_note :: proc(
    ledger: ^Accepted_Ledger($C, $A, $N),
    entry: Accepted_Input(C, A, N),
    confirmed, local_head, authority_head: u64,
) -> Error {
    if len(ledger.entries) != PHYSICS_HISTORY ||
       entry.version != ACCEPTED_PHYSICS_VERSION ||
       entry.epoch != ledger.epoch ||
       entry.tick == 0 {
        return .Invalid_Input
    }

    if entry.tick > authority_head || authority_head - entry.tick >= PHYSICS_HISTORY {
        return .Invalid_Time
    }

    if entry.tick > local_head && entry.tick - local_head >= PHYSICS_HISTORY {
        return .Invalid_Time
    }

    prior := &ledger.entries[entry.tick % PHYSICS_HISTORY]

    if prior.tick == entry.tick && prior.epoch == entry.epoch {
        return reflect.equal(prior^, entry) ? .None : .Invalid_Input
    }

    if entry.tick <= confirmed || entry.tick <= ledger.baseline {
        return .Invalid_Time
    }

    if prior.tick != 0 && prior.tick > entry.tick {
        return .Invalid_Time
    }

    return .None
}

accepted_note :: proc(
    ledger: ^Accepted_Ledger($C, $A, $N),
    entry: Accepted_Input(C, A, N),
    confirmed, local_head, authority_head: u64,
) -> Error {
    if error := accepted_can_note(ledger, entry, confirmed, local_head, authority_head); error != .None {
        return error
    }

    ledger.entries[entry.tick % PHYSICS_HISTORY] = entry
    ledger.newest = max(ledger.newest, entry.tick)
    return .None
}

accepted_validate :: proc(entry: Accepted_Input($C, $A, $N), model: Model($S, C, A, $E, N)) -> bool {
    if entry.version != ACCEPTED_PHYSICS_VERSION || entry.epoch == 0 || entry.tick == 0 || model.control_valid == nil {
        return false
    }

    b := entry.batch

    if b.prediction_group != 0 ||
       b.prediction_seat != 0 ||
       !authority_observation_valid(model.authority, b.authority, N) {
        return false
    }

    mask := (u64(1) << uint(N)) - 1

    if (b.joins | b.leaves | b.fresh) & ~mask != 0 || b.fresh & ~b.joins != 0 {
        return false
    }

    for control, seat in b.controls {
        if !model.control_valid(control) {
            return false
        }

        d := entry.decisions

        if d.origins[seat] > .Local {
            return false
        }

        if d.origins[seat] == .Sample || d.origins[seat] == .Held {
            if d.drivers[seat].generation == 0 || d.drivers[seat].serial == 0 {
                return false
            }
        }

        if d.origins[seat] == .Neutral && !reflect.equal(control, model.neutral) {
            return false
        }

        if !b.has_action[seat] {
            if b.sequences[seat] != 0 || b.rejections[seat] != .None || d.applied[seat] || d.verdicts[seat] != .None {
                return false
            }

            continue
        }

        if b.sequences[seat] == 0 ||
           b.sequences[seat] > max(u64) >> 8 ||
           b.rejections[seat] > .Disconnected ||
           d.verdicts[seat] > .Disconnected {
            return false
        }

        if b.rejections[seat] != .None {
            if d.applied[seat] || d.verdicts[seat] != b.rejections[seat] {
                return false
            }
        } else {
            if model.action == nil ||
               model.action_valid == nil ||
               !model.action_valid(b.actions[seat]) ||
               (d.verdicts[seat] != .None && d.verdicts[seat] != .Predicate) ||
               d.applied[seat] != (d.verdicts[seat] == .None) {
                return false
            }
        }
    }

    return true
}

@(private)
physics_control_digest :: proc(s: ^Server($S, $C, $A, $E, $N), control: C, stamp: View_Stamp) -> (bd.Digest, bool) {
    n, m := s.codecs.controls.wire_size, s.codecs.view_stamp.wire_size

    if n + m > len(s.txb) {
        return {}, false
    }

    if sc.encode(&s.codecs.controls, control, s.txb[:n]).error != .None ||
       sc.encode(&s.codecs.view_stamp, stamp, s.txb[n:n + m]).error != .None {
        return {}, false
    }

    return bd.hash_bytes(s.txb[:n + m]), true
}
