package replay_net_test
import "core:testing"
import "core:reflect"
import net "godot:replay/net"
import r "godot:replay"

Intent_Submitter :: struct {
    calls:    int,
    sequence: u64,
    error:    net.Error,
    value:    Action,
}

intent_submitter :: proc(user: rawptr, value: Action) -> (u64, net.Error) {
    s := cast(^Intent_Submitter)user
    s.calls += 1
    s.value = value

    if s.error != .None {
        return 0, s.error
    }

    s.sequence += 1
    return s.sequence, .None
}

@(test)
intent_capture_is_copied_retained_on_failure_and_explicitly_cancellable :: proc(t: ^testing.T) {
    i: net.Action_Intent(Action)
    value := Action {
        take = true,
    }
    testing.expect_value(t, net.intent_capture(&i, value), net.Error.None)
    value.take = false
    testing.expect_value(t, net.intent_capture(&i, Action{fail_after_mutation = true}), net.Error.Capacity)
    s := Intent_Submitter {
        error = .Capacity,
    }

    for error in ([3]net.Error{.Capacity, .Wrong_Phase, .Fenced}) {
        s.error = error
        sequence, returned := net.intent_submit(&i, 1, intent_submitter, &s)
        testing.expect(
            t,
            sequence == 0 &&
            returned == error &&
            i.captured &&
            i.value.take &&
            i.pending_count == 0 &&
            i.submitted == 0,
        )
    }

    testing.expect(t, net.intent_cancel(&i) && !i.captured && i.value == (Action{}))
    _, error := net.intent_submit(&i, 1, intent_submitter, &s)
    testing.expect(t, error == .None && s.calls == 3)
    unsupported: net.Action_Intent(^int)
    number := 1
    testing.expect_value(t, net.intent_capture(&unsupported, &number), net.Error.Invalid_Input)
}

@(test)
intent_ticket_capacity_prevents_submission_and_results_settle_once :: proc(t: ^testing.T) {
    i: net.Action_Intent(Action)
    s: Intent_Submitter

    for _ in 0 ..< net.ACTION_CAPACITY {
        testing.expect_value(t, net.intent_capture(&i, Action{take = true}), net.Error.None)
        _, error := net.intent_submit(&i, 1, intent_submitter, &s)
        testing.expect_value(t, error, net.Error.None)
    }

    testing.expect_value(t, net.intent_capture(&i, Action{fail_after_mutation = true}), net.Error.None)
    _, error := net.intent_submit(&i, 1, intent_submitter, &s)
    testing.expect_value(t, error, net.Error.Capacity)
    testing.expect(t, s.calls == net.ACTION_CAPACITY && i.captured)
    refused := net.Action_Outcome {
        sequence = 2,
        tick     = 20,
        reason   = .Predicate,
    }
    testing.expect(t, net.intent_resolve(&i, 1, refused) && !net.intent_resolve(&i, 1, refused))
    sequence, issued := net.intent_submit(&i, 1, intent_submitter, &s)
    testing.expect(t, issued == .None && sequence == u64(net.ACTION_CAPACITY + 1))
    testing.expect(
        t,
        net.intent_resolve(&i, 1, {sequence = sequence, tick = 21, applied = true}) &&
        !net.intent_resolve(&i, 1, {sequence = 999, tick = 21, applied = true}),
    )
    testing.expect(
        t,
        i.submitted == u64(net.ACTION_CAPACITY + 1) &&
        i.refused == 1 &&
        i.confirmed == 1 &&
        i.pending_count == net.ACTION_CAPACITY - 1,
    )
    testing.expect(t, i.last.ticket.sequence == sequence && i.last.disposition == .Applied && i.has_result)
}

@(test)
intent_cancellation_does_not_cancel_submitted_work_and_bad_receipts_fault :: proc(t: ^testing.T) {
    i: net.Action_Intent(Action)
    s: Intent_Submitter
    net.intent_capture(&i, Action{take = true})
    net.intent_submit(&i, 1, intent_submitter, &s)
    net.intent_capture(&i, Action{fail_after_mutation = true})
    testing.expect(t, net.intent_cancel(&i) && i.pending_count == 1)
    testing.expect(t, !net.intent_resolve(&i, 1, {sequence = 1, applied = true, reason = .Predicate}))
    testing.expect(t, net.intent_resolve(&i, 1, {sequence = 1, tick = 1, applied = true}))
    net.intent_capture(&i, Action{take = true})
    s.sequence = 0 // reuse of a retired ticket is forbidden too
    _, error := net.intent_submit(&i, 1, intent_submitter, &s)
    testing.expect_value(t, error, net.Error.Invalid_Input)
    calls := s.calls
    net.intent_submit(&i, 1, intent_submitter, &s)
    testing.expect(t, s.calls == calls && i.captured && i.fault == .Invalid_Input)
    net.intent_reset(&i)
    testing.expect(t, reflect.equal(i, net.Action_Intent(Action){}))
}

@(test)
client_intent_survives_resync_and_does_not_retry_a_predicate_refusal :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_timing = .Receipt)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    begin_test_resync(c)
    sent := c.stats.tx_packets
    i: net.Action_Intent(Action)
    net.intent_capture(&i, Action{take = true})
    first, error := net.client_intent(c, &i)
    testing.expect(t, error == .None && !i.captured && i.pending_count == 1 && c.stats.tx_packets == sent)
    net.intent_capture(&i, Action{fail_after_mutation = true})
    second, error2 := net.client_intent(c, &i)
    testing.expect(t, error2 == .None && second > first)

    for _ in 0 ..< 160 {
        fixture_step(&f)
    }

    results: [4]net.Action_Outcome
    n := net.client_outcomes(c, results[:])
    testing.expect_value(t, n, 2)

    for outcome in results[:n] {
        testing.expect(t, net.intent_resolve(&i, 1, outcome) && !net.intent_resolve(&i, 1, outcome))
    }

    testing.expect(t, i.confirmed == 1 && i.refused == 1 && i.pending_count == 0 && !i.captured)
    before := c.next_action
    net.client_intent(c, &i)
    testing.expect_value(t, c.next_action, before)
    world, _ := r.current(&f.server.timeline)
    testing.expect(t, world.state.players[0].bag == 5 && world.state.players[0].x == 0)
}

@(test)
server_intent_uses_the_existing_authority_action_path :: proc(t: ^testing.T) {
    s: Server
    defer net.server_destroy(&s)
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(World){state = {chest = 5}}, model(), {}, local_seat = 1),
        net.Error.None,
    )
    net.server_step(&s)
    i: net.Action_Intent(Action)
    net.intent_capture(&i, Action{take = true})
    sequence, error := net.server_intent(&s, &i)
    testing.expect(t, error == .None && sequence > 0 && i.pending_count == 1)
    net.server_step(&s)
    world, _ := r.current(&s.timeline)
    testing.expect(t, world.state.players[0].bag == 5)
    events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
    n, _ := r.copy_events(&s.timeline, world.tick, events[:])

    for event in events[:n] {
        if event.value.kind == .Action_Result {
            testing.expect(
                t,
                net.intent_resolve(
                    &i,
                    1,
                    {
                        sequence = event.value.sequence,
                        tick = world.tick,
                        applied = event.value.applied,
                        reason = event.value.reason,
                    },
                ),
            )
        }
    }

    testing.expect(t, i.confirmed == 1 && i.pending_count == 0)
}

@(test)
intent_recovery_preserves_dispositions_and_fences_reused_sequences_by_epoch :: proc(t: ^testing.T) {
    i: net.Action_Intent(Action)
    s: Intent_Submitter

    for _ in 0 ..< 5 {
        net.intent_capture(&i, Action{take = true})
        net.intent_submit(&i, 1, intent_submitter, &s)
    }

    report := net.Client_Recovery {
        from_epoch     = 1,
        to_epoch       = 2,
        old_seat       = 1,
        new_seat       = 1,
        recovered_tick = 50,
        received       = 4,
        settled        = 3,
        count          = 5,
    }
    report.actions[0] = {
        epoch = 1,
        sequence = 1,
        disposition = .Applied,
        outcome = {sequence = 1, tick = 40, applied = true},
    }
    report.actions[1] = {
        epoch = 1,
        sequence = 2,
        disposition = .Rejected,
        outcome = {sequence = 2, tick = 41, reason = .Predicate},
    }
    report.actions[2] = {
        epoch       = 1,
        sequence    = 3,
        disposition = .Settled_Unknown,
    }
    report.actions[3] = {
        epoch       = 1,
        sequence    = 4,
        disposition = .Retained,
    }
    report.actions[4] = {
        epoch       = 1,
        sequence    = 5,
        disposition = .Retired,
    }
    testing.expect_value(t, net.intent_recover(&i, report), net.Error.None)
    testing.expect(
        t,
        i.pending_count == 1 &&
        i.pending[0] == (net.Intent_Ticket{2, 4}) &&
        i.confirmed == 1 &&
        i.refused == 1 &&
        i.unknown == 1 &&
        i.retired == 1 &&
        i.result_serial == 4,
    )
    before := i
    testing.expect_value(t, net.intent_recover(&i, report), net.Error.None)
    testing.expect(t, reflect.equal(before, i))
    // Sequence 5 was retired in epoch 1; the new ledger may now allocate 5 again.
    s.sequence = 4
    net.intent_capture(&i, Action{take = true})
    sequence, error := net.intent_submit(&i, 2, intent_submitter, &s)
    testing.expect(t, error == .None && sequence == 5)
    testing.expect(t, !net.intent_resolve(&i, 1, {sequence = 5, tick = 60, applied = true}))
    testing.expect(t, net.intent_resolve(&i, 2, {sequence = 5, tick = 60, applied = true}))
    testing.expect(
        t,
        !net.intent_resolve(&i, 1, {sequence = 4, tick = 60, applied = true}) &&
        net.intent_resolve(&i, 2, {sequence = 4, tick = 61, applied = true}),
    )
    testing.expect(t, i.confirmed == 3 && i.pending_count == 0 && i.submitted == 5 + 1)
}

@(test)
invalid_intent_recovery_report_cannot_partially_retire_tickets :: proc(t: ^testing.T) {
    i: net.Action_Intent(Action)
    s: Intent_Submitter

    for _ in 0 ..< 2 {
        net.intent_capture(&i, Action{take = true})
        net.intent_submit(&i, 1, intent_submitter, &s)
    }

    report := net.Client_Recovery {
        from_epoch = 1,
        to_epoch   = 2,
        received   = 1,
        settled    = 0,
        count      = 2,
    }
    report.actions[0] = {
        epoch       = 1,
        sequence    = 1,
        disposition = .Retained,
    }
    report.actions[1] = {
        epoch       = 1,
        sequence    = 2,
        disposition = .Retained,
    } // outside received frontier
    before := i
    testing.expect_value(t, net.intent_recover(&i, report), net.Error.Invalid_Input)
    testing.expect(t, reflect.equal(before, i))
}
