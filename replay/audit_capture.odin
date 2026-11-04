package replay

import "core:mem"

// Diagnostic owner, populated only for the first state/event audit mismatch.
// Every captured value is independent of the timeline and replay scratch.
// Call audit_capture_destroy before reuse; copying this owner aliases its arrays.
Audit_Capture :: struct($State, $Input, $Event: typeid) {
    allocator:                          mem.Allocator,
    ready:                              bool,
    result:                             Result,
    parent, expected, actual:           Frame(State),
    input:                              Input,
    expected_events, actual_events:     []Occurrence(Event),
    expected_complete, actual_complete: ^Complete_Checkpoint(State, Event),
    external_error:                     Error,
}

audit_capture_destroy :: proc(capture: ^Audit_Capture($S, $I, $E)) {
    if capture.expected_complete != nil {
        complete_checkpoint_destroy(capture.expected_complete)
        free(capture.expected_complete, capture.allocator)
    }

    if capture.actual_complete != nil {
        complete_checkpoint_destroy(capture.actual_complete)
        free(capture.actual_complete, capture.allocator)
    }

    delete(capture.expected_events, capture.allocator)
    delete(capture.actual_events, capture.allocator)
    capture^ = {}
}

// This is one audit execution, not an audit followed by a second replay which
// could observe different illegal external state. No report is produced for a
// successful audit, missing history, or an aborted simulation step.
audit_capture :: proc(
    t: ^Timeline($S, $I, $E),
    from_tick: u64,
    capture: ^Audit_Capture(S, I, E),
    allocator := context.allocator,
) -> Result {
    if capture == nil || capture.ready || len(capture.expected_events) != 0 || len(capture.actual_events) != 0 {
        return {error = .Invalid_Config, tick = from_tick}
    }

    return replay_suffix_capture(t, from_tick, I{}, true, capture, allocator)
}

@(private)
capture_audit_difference :: proc(
    capture: ^Audit_Capture($S, $I, $E),
    result: Result,
    expected, actual: ^Record(S, I, E),
    parent: Frame(S),
    allocator: mem.Allocator,
    external: External = {},
    epoch: u64 = 1,
) {
    if capture == nil {
        return
    }

    capture.allocator, capture.result, capture.expected, capture.actual, capture.input =
        allocator, result, expected.frame, actual.frame, expected.input
    capture.parent = parent
    capture.expected_events = make([]Occurrence(E), expected.count, allocator)
    capture.actual_events = make([]Occurrence(E), actual.count, allocator)
    copy(capture.expected_events, expected.events[:expected.count])
    copy(capture.actual_events, actual.events[:actual.count])

    if external.identity != 0 {
        left, left_err := external.clone(expected.image)

        if left == nil && left_err == .None {
            left_err = .External_State
        }

        if left_err != .None {
            if left != nil {
                external.release(left)
            }

            capture.external_error = left_err
        } else {
            right, right_err := external.clone(actual.image)

            if right == nil && right_err == .None {
                right_err = .External_State
            }

            if right_err != .None {
                external.release(left)

                if right != nil {
                    external.release(right)
                }

                capture.external_error = right_err
            } else {
                left_checkpoint, left_adopt := complete_checkpoint_adopt(
                    expected.frame,
                    E,
                    external,
                    left,
                    expected.image_bytes,
                    epoch,
                    expected.events[:expected.count],
                    allocator,
                )

                if left_adopt != .None {
                    external.release(left)
                    external.release(right)
                    capture.external_error = left_adopt
                } else {
                    right_checkpoint, right_adopt := complete_checkpoint_adopt(
                        actual.frame,
                        E,
                        external,
                        right,
                        actual.image_bytes,
                        epoch,
                        actual.events[:actual.count],
                        allocator,
                    )

                    if right_adopt != .None {
                        complete_checkpoint_destroy(&left_checkpoint)
                        external.release(right)
                        capture.external_error = right_adopt
                    } else {
                        capture.expected_complete = new(Complete_Checkpoint(S, E), allocator)
                        capture.expected_complete^ = left_checkpoint
                        capture.actual_complete = new(Complete_Checkpoint(S, E), allocator)
                        capture.actual_complete^ = right_checkpoint
                    }
                }
            }
        }
    }

    capture.ready = true
}

// Find the latest replayable suffix, stopping at a checkpoint/correction boundary.
// No state/input/event copies or allocations are needed to inspect this metadata.
audit_window :: proc(t: ^Timeline($S, $I, $E), max_ticks: int = 120) -> (from_tick, to_tick: u64, error: Error) {
    if err := available(t); err != .None {
        return 0, 0, err
    }

    if max_ticks < 1 || max_ticks > 4096 {
        return 0, 0, .Invalid_Config
    }

    to_tick = t.head
    last := record_at(t, t.head)

    if last == nil {
        return 0, to_tick, .History_Missing
    }

    if !last.has_input {
        return 0, to_tick, .Initial_Frame
    }

    from_tick = t.head

    for count := 0; count < max_ticks; count += 1 {
        if from_tick == 0 {
            return 0, to_tick, .Initial_Frame
        }

        parent := record_at(t, from_tick - 1)

        if parent == nil {
            if count == 0 {
                return 0, to_tick, .History_Missing
            }

            from_tick += 1
            break
        }

        if !parent.has_input || count + 1 == max_ticks {
            break
        }

        from_tick -= 1
    }

    return from_tick, to_tick, .None
}

audit_recent :: proc(
    t: ^Timeline($S, $I, $E),
    capture: ^Audit_Capture(S, I, E),
    max_ticks: int = 120,
    allocator := context.allocator,
) -> Result {
    from, to, err := audit_window(t, max_ticks)

    if err != .None {
        return {error = err, tick = to}
    }

    return audit_capture(t, from, capture, allocator)
}
