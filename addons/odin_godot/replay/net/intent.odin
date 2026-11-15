package replay_net

import r "godot:replay"

// Caller-owned input state, outside the simulation. One copied unsubmitted
// action plus bounded tickets already owned by the network action ledger.
Intent_Ticket :: struct {
    epoch, sequence: u64,
}

Intent_Disposition :: enum {
    Applied,
    Rejected,
    Retired,
    Unknown,
}

Intent_Result :: struct {
    ticket:      Intent_Ticket,
    tick:        u64,
    disposition: Intent_Disposition,
    reason:      Action_Reason,
}

Action_Intent :: struct($Action: typeid) {
    captured:                                        bool,
    value:                                           Action,
    pending:                                         [ACTION_CAPACITY]Intent_Ticket,
    pending_count:                                   int,
    submitted, confirmed, refused, retired, unknown: u64,
    highest_epoch, highest_sequence:                 u64,
    last:                                            Intent_Result,
    has_result:                                      bool,
    result_serial:                                   u64,
    fault:                                           Error,
}

intent_capture :: proc(i: ^Action_Intent($A), value: A) -> Error {
    if i.fault != .None {
        return i.fault
    }

    if !r.value_supported(A) {
        return .Invalid_Input
    }

    if i.captured {
        return .Capacity
    }

    i.value, i.captured = value, true
    return .None
}

// Cancellation affects only an action not yet accepted by the submitter.
intent_cancel :: proc(i: ^Action_Intent($A)) -> bool {
    was := i.captured
    i.captured = false
    i.value = {}
    return was
}

// A submitter must enqueue once and return a nonzero unique sequence on success.
// It must not synchronously resolve or reenter this intent. Session/Room and
// client/server issue procedures satisfy that contract. A broken receipt faults
// the helper rather than automatically repeating an untrackable submission.
intent_submit :: proc(
    i: ^Action_Intent($A),
    epoch: u64,
    submit: proc(_: rawptr, _: A) -> (u64, Error),
    user: rawptr,
) -> (
    u64,
    Error,
) {
    if i.fault != .None {
        return 0, i.fault
    }

    if !i.captured {
        return 0, .None
    }

    if submit == nil || epoch == 0 {
        return 0, .Invalid_Config
    }

    if epoch < i.highest_epoch {
        return 0, .Fenced
    }

    if i.pending_count == len(i.pending) || i.submitted == max(u64) {
        return 0, .Capacity
    }

    sequence, error := submit(user, i.value)

    if error != .None {
        return 0, error
    }

    valid := sequence != 0 && (epoch > i.highest_epoch || sequence > i.highest_sequence)

    if !valid {
        i.fault = .Invalid_Input
        return 0, i.fault
    }

    i.pending[i.pending_count] = {epoch, sequence}
    i.pending_count += 1
    i.submitted += 1
    i.highest_epoch, i.highest_sequence = epoch, sequence
    i.captured = false
    i.value = {}
    return sequence, .None
}

// Only authoritative outcomes belong here. Unknown or duplicate tickets do
// nothing; a predicate refusal completes the ticket without retrying gameplay.
intent_resolve :: proc(i: ^Action_Intent($A), epoch: u64, outcome: Action_Outcome) -> bool {
    if outcome.sequence == 0 || outcome.reason > .Disconnected || outcome.applied != (outcome.reason == .None) {
        return false
    }

    for pending, index in i.pending[:i.pending_count] {
        if pending != (Intent_Ticket{epoch, outcome.sequence}) {
            continue
        }

        if outcome.applied {
            i.confirmed += 1
        } else {
            i.refused += 1
        }

        i.last, i.has_result = {pending, outcome.tick, outcome.applied ? .Applied : .Rejected, outcome.reason}, true
        i.result_serial += 1
        copy(i.pending[index:], i.pending[index + 1:i.pending_count])
        i.pending_count -= 1
        return true
    }

    return false
}

// Reset at an explicit local session lifecycle boundary. This does not cancel
// requests already owned by a running network ledger.
intent_reset :: proc(i: ^Action_Intent($A)) {
    i^ = {}
}

// Apply every authority-recovery report before consuming its new-epoch results.
// Retained requests keep their IDs in the new epoch; absent durable work is not
// resubmitted. Unknown results remain distinct from a gameplay rejection.
intent_recover :: proc(i: ^Action_Intent($A), report: Client_Recovery) -> Error {
    report := report

    if report.from_epoch == 0 {
        return .None
    }

    if report.to_epoch <= report.from_epoch || report.count > ACTION_CAPACITY || report.settled > report.received {
        return .Invalid_Input
    }

    for entry, index in report.actions[:report.count] {
        if entry.epoch != report.from_epoch || entry.sequence == 0 || entry.disposition > .Settled_Unknown {
            return .Invalid_Input
        }

        for prior in report.actions[:index] {
            if prior.sequence == entry.sequence {
                return .Invalid_Input
            }
        }

        if entry.disposition == .Applied || entry.disposition == .Rejected {
            if entry.sequence > report.settled ||
               entry.outcome.sequence != entry.sequence ||
               entry.outcome.reason > .Disconnected ||
               entry.outcome.applied != (entry.disposition == .Applied) ||
               entry.outcome.applied != (entry.outcome.reason == .None) {
                return .Invalid_Input
            }
        }

        if entry.disposition == .Retained && (entry.sequence <= report.settled || entry.sequence > report.received) {
            return .Invalid_Input
        }

        if entry.disposition == .Retired && entry.sequence <= report.received {
            return .Invalid_Input
        }

        if entry.disposition == .Settled_Unknown && entry.sequence > report.settled {
            return .Invalid_Input
        }
    }

    kept := 0

    for ticket in i.pending[:i.pending_count] {
        if ticket.epoch != report.from_epoch {
            i.pending[kept] = ticket
            kept += 1
            continue
        }

        if ticket.sequence > report.settled && ticket.sequence <= report.received {
            i.pending[kept] = {report.to_epoch, ticket.sequence}
            kept += 1
            continue
        }

        result := Intent_Result {
            ticket      = ticket,
            tick        = report.recovered_tick,
            disposition = ticket.sequence > report.received ? .Retired : .Unknown,
        }

        for entry in report.actions[:report.count] {
            if entry.sequence == ticket.sequence && (entry.disposition == .Applied || entry.disposition == .Rejected) {
                result.tick, result.reason = entry.outcome.tick, entry.outcome.reason
                result.disposition = entry.disposition == .Applied ? .Applied : .Rejected
                break
            }
        }

        switch result.disposition {
        case .Applied:
            i.confirmed += 1
        case .Rejected:
            i.refused += 1
        case .Retired:
            i.retired += 1
        case .Unknown:
            i.unknown += 1
        }

        i.last, i.has_result = result, true
        i.result_serial += 1
    }

    i.pending_count = kept

    if report.to_epoch > i.highest_epoch {
        i.highest_epoch, i.highest_sequence = report.to_epoch, report.received
    } else if report.to_epoch == i.highest_epoch {
        i.highest_sequence = max(i.highest_sequence, report.received)
    }

    return .None
}

client_intent :: proc(c: ^Client($S, $C, $A, $E, $N), i: ^Action_Intent(A)) -> (u64, Error) {
    if !c.initialized {
        return 0, .Wrong_Phase
    }

    if !c.recovering {
        if error := intent_recover(i, c.recovery); error != .None {
            return 0, error
        }
    }

    return intent_submit(i, c.cfg.epoch, proc(user: rawptr, a: A) -> (u64, Error) {
            return client_issue(cast(^Client(S, C, A, E, N))user, a)
        }, c)
}

server_intent :: proc(s: ^Server($S, $C, $A, $E, $N), i: ^Action_Intent(A)) -> (u64, Error) {
    if !s.initialized {
        return 0, .Wrong_Phase
    }

    return intent_submit(i, s.cfg.epoch, proc(user: rawptr, a: A) -> (u64, Error) {
            return server_issue(cast(^Server(S, C, A, E, N))user, a)
        }, s)
}
